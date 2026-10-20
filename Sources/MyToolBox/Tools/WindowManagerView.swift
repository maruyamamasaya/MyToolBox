import SwiftUI
import ApplicationServices

@MainActor final class WindowManagerModel: ObservableObject {
    static let shared = WindowManagerModel()
    @Published var status = "配置するアプリを選んでから、この画面のボタンを押してください。"
    @Published var targetName = "未選択"
    @Published var trusted: Bool
    @Published var shortcutsEnabled = false
    @Published private(set) var shortcutsRequested = false
    private var target: NSRunningApplication?
    private var observer: NSObjectProtocol?
    private var originals: [(AXUIElement, CGRect)] = []
    private let defaults: UserDefaults
    private let registration: WindowManagerShortcutRegistration
    private let trustReader: () -> Bool
    private let trackApplications: Bool
    private let applyOverride: ((WindowLayout) -> Void)?
    // Physical key codes; all shortcuts use Control + Option.
    static let keys: [(WindowLayout, UInt32, String)] = [
        (.left, 123, "←"), (.right, 124, "→"), (.top, 126, "↑"), (.bottom, 125, "↓"),
        (.maximize, 36, "Return"), (.restore, 51, "Delete"), (.center, 8, "C"),
        (.thirdLeft, 18, "1"), (.thirdCenter, 19, "2"), (.thirdRight, 20, "3"),
        (.twoThirdsLeft, 21, "4"), (.twoThirdsRight, 23, "5"),
        (.topLeft, 12, "Q"), (.topRight, 13, "W"), (.bottomLeft, 0, "A"), (.bottomRight, 1, "S")]
    init(defaults: UserDefaults = IndependentTools.defaults, registration: WindowManagerShortcutRegistration? = nil,
         trustReader: @escaping () -> Bool = { AXIsProcessTrusted() }, trackApplications: Bool = true,
         applyOverride: ((WindowLayout) -> Void)? = nil) {
        self.defaults = defaults; self.registration = registration ?? CarbonWindowManagerShortcuts()
        self.trustReader = trustReader; self.trackApplications = trackApplications; self.applyOverride = applyOverride
        trusted = trustReader()
        if trackApplications {
            select(NSWorkspace.shared.frontmostApplication)
            observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                Task { @MainActor in self?.select(app) }
            }
        }
        restoreShortcuts()
    }
    static func isEligibleTarget(bundleIdentifier: String?, processIdentifier: pid_t, ownProcessIdentifier: pid_t, policy: NSApplication.ActivationPolicy) -> Bool {
        processIdentifier != ownProcessIdentifier && policy == .regular && bundleIdentifier != "local.MyToolBox" &&
            !(bundleIdentifier?.hasPrefix("local.MyToolBox.tool.") ?? false)
    }
    private func select(_ app: NSRunningApplication?) {
        guard let app, Self.isEligibleTarget(bundleIdentifier: app.bundleIdentifier, processIdentifier: app.processIdentifier,
                                           ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier, policy: app.activationPolicy) else { return }
        target = app; targetName = app.localizedName ?? "アプリ"
    }
    func refresh() {
        trusted = trustReader()
        if trackApplications { select(NSWorkspace.shared.frontmostApplication) }
    }
    func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func restoreShortcuts() {
        defaults.synchronize()
        shortcutsRequested = defaults.bool(forKey: IndependentTools.windowManagerShortcutsKey)
        applyShortcuts(shortcutsRequested)
    }
    func setShortcuts(_ enabled: Bool) {
        defaults.set(enabled, forKey: IndependentTools.windowManagerShortcutsKey)
        shortcutsRequested = enabled
        applyShortcuts(enabled)
    }
    private func applyShortcuts(_ enabled: Bool) {
        registration.unregister(); shortcutsEnabled = false
        guard enabled else { status = "ショートカットは無効です。画面のボタンから配置できます。"; return }
        if let (index, code) = registration.register(keyCodes: Self.keys.map { $0.1 }, onPress: { [weak self] index in
            guard Self.keys.indices.contains(index) else { return }
            self?.apply(Self.keys[index].0)
        }) {
            registration.unregister()
            let name = Self.keys.indices.contains(index) ? Self.keys[index].2 : "?"
            status = "⌃⌥\(name) は登録できません。他のアプリのショートカットを確認してください（\(code)）。"
            return
        }
        shortcutsEnabled = true
        status = "ショートカットを有効にしました。対象アプリを前面にして操作できます。"
    }
    func stop() {
        registration.unregister(); shortcutsEnabled = false
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer); self.observer = nil }
    }
    private func attribute(_ window: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(window, name as CFString, &value) == .success ? value : nil
    }
    private func frame(_ window: AXUIElement) -> CGRect? {
        guard let p = attribute(window, kAXPositionAttribute), let s = attribute(window, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
    private func write(_ rect: CGRect, to window: AXUIElement) -> Bool {
        var point = rect.origin, size = rect.size
        guard let p = AXValueCreate(.cgPoint, &point), let s = AXValueCreate(.cgSize, &size) else { return false }
        // A second size request handles apps which constrain size on the old display.
        let first = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s)
        let moved = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, p)
        let resized = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, s)
        return moved == .success && (first == .success || resized == .success)
    }
    func apply(_ layout: WindowLayout) {
        if let applyOverride { applyOverride(layout); return }
        refresh()
        guard trusted else { status = "システム設定で独立版「ウィンドウマネージャー」のアクセシビリティを許可し、「許可を再確認」を押してください。"; return }
        guard let target, !target.isTerminated else { status = "操作するアプリがありません。先に対象のウィンドウを選んでください。"; return }
        let app = AXUIElementCreateApplication(target.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 1)
        guard let raw = attribute(app, kAXFocusedWindowAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { status = "対象アプリのウィンドウを取得できません。"; return }
        let window = raw as! AXUIElement
        AXUIElementSetMessagingTimeout(window, 1)
        guard (attribute(window, "AXFullScreen") as? Bool) != true else { status = "フルスクリーンを解除してから配置してください。"; return }
        guard let current = frame(window), let primary = NSScreen.screens.first else { status = "ウィンドウの位置・サイズを取得できません。"; return }
        var movable = DarwinBoolean(false), resizable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &movable) == .success, movable.boolValue,
              AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &resizable) == .success, resizable.boolValue else { status = "このウィンドウは移動・サイズ変更に対応していません。"; return }
        let screen = NSScreen.screens.max { a, b in
            let ar = WindowLayout.accessibilityFrame(a.frame, primaryHeight: primary.frame.maxY).intersection(current)
            let br = WindowLayout.accessibilityFrame(b.frame, primaryHeight: primary.frame.maxY).intersection(current)
            return (ar.isNull ? 0 : ar.width * ar.height) < (br.isNull ? 0 : br.width * br.height)
        } ?? primary
        let area = WindowLayout.accessibilityFrame(screen.visibleFrame, primaryHeight: primary.frame.maxY)
        let previous = originals.first { CFEqual($0.0, window) }
        let desired: CGRect
        if layout == .restore {
            guard let previous else { status = "このウィンドウの復元位置はまだありません。"; return }
            desired = previous.1
        } else {
            guard let rect = layout.frame(in: area, current: current) else { return }; desired = rect
            if previous == nil {
                if originals.count >= 100 { originals.removeFirst() }
                originals.append((window, current))
            }
        }
        guard write(desired, to: window) else { status = "配置を完了できませんでした。一部だけ変更された可能性があります。「元の位置に戻す」を試してください。"; return }
        guard let actual = frame(window) else { status = "配置を要求しましたが、結果の位置を確認できませんでした。"; return }
        if abs(actual.width - desired.width) > 3 || abs(actual.height - desired.height) > 3 || abs(actual.minX - desired.minX) > 3 || abs(actual.minY - desired.minY) > 3 {
            status = "配置を要求しましたが、アプリのサイズ制限などで指定位置と一致しません。"; return
        }
        if layout == .restore { originals.removeAll { CFEqual($0.0, window) } }
        status = "\(targetName)：\(layout.title)に配置しました。"
    }
}

struct WindowManagerView: View {
    @ObservedObject var model = WindowManagerModel.shared
    var body: some View {
        ToolPage("ウィンドウマネージャー", subtitle: "使いたい位置へ、ウィンドウをすばやく配置", symbol: "rectangle.split.2x2", tint: .cyan) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ToolCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("対象アプリ：\(model.targetName)").font(.headline)
                            Text("MyToolBoxを開く直前に使っていたアプリの、選択中のウィンドウを操作します。").font(.caption).foregroundStyle(.secondary)
                            Label(model.trusted ? "アクセシビリティ：許可済み" : "アクセシビリティ：許可が必要", systemImage: model.trusted ? "checkmark.shield" : "lock.shield")
                            HStack {
                                Button("システム設定を開く") { model.openSettings() }
                                Button("許可を再確認") { model.refresh() }
                            }
                        }
                    }
                    ToolCard {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(WindowLayout.allCases) { layout in
                                Button { model.apply(layout) } label: {
                                    VStack(spacing: 7) {
                                        LayoutPreview(layout: layout).frame(width: 52, height: 34)
                                        Text(layout.title).font(.caption)
                                        if let key = WindowManagerModel.keys.first(where: { $0.0 == layout })?.2 { Text("⌃⌥" + key).font(.caption2).foregroundStyle(.secondary) }
                                    }.frame(maxWidth: .infinity, minHeight: 85)
                                }.disabled(!model.trusted)
                            }
                        }
                    }
                    ToolCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("グローバルショートカット", isOn: Binding(get: { model.shortcutsRequested }, set: { model.setShortcuts($0) }))
                            Text("Control + Option と表示のキーで配置。ON/OFFは再起動後も保持します。キー割り当ては固定です。").font(.caption).foregroundStyle(.secondary)
                            Text(model.status).font(.callout).textSelection(.enabled)
                        }
                    }
                    ToolFootnote(text: "Dock・メニューバーを除く領域に配置します。復元位置はアプリ終了まで保持。フルスクリーン・固定サイズなど、操作できないウィンドウもあります。")
                }.padding(24)
            }
        }.frame(width: 720, height: 690).onAppear { model.refresh() }
    }
}
private struct LayoutPreview: View {
    let layout: WindowLayout
    var body: some View {
        GeometryReader { geo in
            let area = CGRect(origin: .zero, size: geo.size)
            let rect = layout.frame(in: area, current: CGRect(x: 0, y: 0, width: geo.size.width * 0.6, height: geo.size.height * 0.65)) ?? area.insetBy(dx: 8, dy: 6)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 3).stroke(.secondary, lineWidth: 1)
                Rectangle().fill(Color.cyan.opacity(0.45)).frame(width: max(0, rect.width - 4), height: max(0, rect.height - 4)).offset(x: rect.minX + 2, y: rect.minY + 2)
            }
        }
    }
}
