import SwiftUI
import ApplicationServices
import Carbon

private struct ShortcutAuditResult: Sendable {
    var rows: [AuditedShortcut] = []
    var coverage: [String] = []
}
private enum ShortcutAuditReader {
    static func read(apps: [(String, Int32)], trusted: Bool) -> ShortcutAuditResult {
        var result = ShortcutAuditResult()
        if let domain = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString) as? [String: Any] {
            for (identifier, raw) in domain {
                guard let item = raw as? [String: Any], item["enabled"] as? Bool == true,
                      let value = item["value"] as? [String: Any], value["type"] as? String == "standard",
                      let params = value["parameters"] as? [Int], params.count >= 3, params[1] >= 0, params[1] < 65535 else { continue }
                let flags = params[2]
                let mods = ((flags & (1 << 20)) != 0 ? 256 : 0) | ((flags & (1 << 17)) != 0 ? 512 : 0) | ((flags & (1 << 19)) != 0 ? 2048 : 0) | ((flags & (1 << 18)) != 0 ? 4096 : 0)
                result.rows.append(.init(owner: "macOS", action: "システム設定 ID \(identifier)", keyCode: params[1], modifiers: mods, global: true, source: "AppleSymbolicHotKeys（設定値）", availability: .configured))
            }
            result.coverage.append("macOS：有効な標準システム設定を読込済み（実際の登録状態は未確認）")
        } else { result.coverage.append("macOS：システム設定を取得できません") }
        for (name, pid) in apps {
            guard trusted else { result.coverage.append("\(name)：未確認（アクセシビリティ権限が必要）"); continue }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.2)
            func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
                var value: CFTypeRef?
                guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
                return value
            }
            guard let menuValue = attribute(app, kAXMenuBarAttribute) else { result.coverage.append("\(name)：未確認（メニュー取得不可）"); continue }
            let menu = unsafeBitCast(menuValue, to: AXUIElement.self)
            var visited = 0, incomplete = false
            let deadline = Date().addingTimeInterval(3)
            let before = result.rows.count
            func walk(_ element: AXUIElement, _ path: String, _ depth: Int) {
                guard depth < 16, visited < 2500, Date() < deadline else { incomplete = true; return }
                visited += 1
                let title = attribute(element, kAXTitleAttribute) as? String ?? ""
                let full = [path, title].filter { !$0.isEmpty }.joined(separator: " → ")
                if let code = attribute(element, kAXMenuItemCmdVirtualKeyAttribute) as? Int,
                   let flags = attribute(element, kAXMenuItemCmdModifiersAttribute) as? Int {
                    let mods = (flags & 8 == 0 ? 256 : 0) | (flags & 1 != 0 ? 512 : 0) | (flags & 2 != 0 ? 2048 : 0) | (flags & 4 != 0 ? 4096 : 0)
                    let enabled = attribute(element, kAXEnabledAttribute) as? Bool
                    result.rows.append(.init(owner: name, action: full, keyCode: code, modifiers: mods, global: false,
                                             source: "アクセシビリティ・メニュー", availability: enabled.map { $0 ? .enabled : .disabled } ?? .unknown))
                }
                if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                    for child in children { walk(child, full, depth + 1); if Date() >= deadline { incomplete = true; break } }
                }
            }
            walk(menu, "", 0)
            result.coverage.append("\(name)：メニュー \(result.rows.count - before)件\(incomplete ? "（一部未確認・取得上限あり）" : "")／独自グローバルキーは未確認")
        }
        return result
    }
}

@MainActor final class ShortcutAuditModel: ObservableObject {
    @Published var rows: [AuditedShortcut] = []
    @Published var coverage: [String] = []
    @Published var busy = false
    @Published var checkedAt: Date?
    func scan() {
        guard !busy else { return }; busy = true
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy != .prohibited }.map { ($0.localizedName ?? $0.bundleIdentifier ?? "不明", $0.processIdentifier) }
        let trusted = AXIsProcessTrusted()
        Task {
            let result = await Task.detached(priority: .userInitiated) { ShortcutAuditReader.read(apps: apps, trusted: trusted) }.value
            rows = result.rows; coverage = result.coverage; checkedAt = Date(); busy = false
        }
    }
}
struct ShortcutAuditView: View {
    @StateObject private var model: ShortcutAuditModel
    @State private var expanded: Bool
    @State private var showsHelp = false
    init(model: ShortcutAuditModel? = nil, initiallyExpanded: Bool = false) {
        _model = StateObject(wrappedValue: model ?? ShortcutAuditModel())
        _expanded = State(initialValue: initiallyExpanded)
    }
    @State private var query = ""
    @State private var onlyCandidates = false
    private func key(_ row: AuditedShortcut) -> String {
        let prefix = (row.modifiers & 4096 != 0 ? "⌃" : "") + (row.modifiers & 2048 != 0 ? "⌥" : "") + (row.modifiers & 512 != 0 ? "⇧" : "") + (row.modifiers & 256 != 0 ? "⌘" : "")
        let names = [0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V", 11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 31:"O", 32:"U", 34:"I", 35:"P", 37:"L", 38:"J", 40:"K", 45:"N", 46:"M", 36:"Return", 48:"Tab", 49:"Space", 51:"Delete", 53:"Esc", 123:"←", 124:"→", 125:"↓", 126:"↑"]
        return prefix + (names[row.keyCode] ?? "KeyCode \(row.keyCode)")
    }
    var body: some View {
        let candidates = AuditedShortcut.candidates(in: model.rows)
        let visible = model.rows.filter { (!onlyCandidates || candidates.contains($0.id)) && (query.isEmpty || "\(key($0)) \($0.owner) \($0.action)".localizedCaseInsensitiveContains(query)) }.sorted { key($0) < key($1) }
        VStack(spacing: 8) {
            HStack {
                Label("ショートカット競合", systemImage: "keyboard").font(.headline)
                Spacer()
                Button { expanded.toggle() } label: {
                    Label(expanded ? "小さく戻す" : "拡大", systemImage: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                ThemeMenu()
            }
            HStack {
                Button(model.busy ? "確認中…" : "Macをチェック", systemImage: "magnifyingglass") { model.scan() }.disabled(model.busy)
                if model.busy { ProgressView().controlSize(.small) }
                Spacer()
                Button { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) } label: {
                    Image(systemName: "lock.shield").frame(width: 24, height: 24)
                }.accessibilityLabel("アクセシビリティ設定を開く")
                Button { showsHelp.toggle() } label: { Image(systemName: "questionmark.circle").frame(width: 24, height: 24) }
                    .accessibilityLabel("確認範囲と権限の説明")
                    .popover(isPresented: $showsHelp) {
                        Text("「メニューで有効」は確認時点のメニュー項目が有効、「今は無効」は無効、「設定で有効」はmacOS設定上の有効を示します。実際のキー入力の到達や独自グローバルキーの動作は未確認です。権限を許可後、再チェックしてください。設定の変更やキー入力の監視は行いません。競合候補は適用範囲が重なる同じキーです。実際の横取り元は断定できません。各アプリ独自のグローバルキー・キー変更ツールは未対応です。")
                            .font(.caption).padding(16).frame(width: 300)
                    }
            }
            TextField("キー・アプリ・動作で検索", text: $query).textFieldStyle(.roundedBorder)
            HStack {
                Toggle("競合候補のみ", isOn: $onlyCandidates).toggleStyle(.checkbox)
                Spacer()
                Text("取得 \(model.rows.count)・候補 \(candidates.count)").font(.caption).foregroundStyle(.secondary)
            }
            if let date = model.checkedAt { Text("確認：\(date.formatted())").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if model.checkedAt == nil && !model.busy { Text("チェックするとショートカットと有効状態を表示します。").foregroundStyle(.secondary) }
                    if model.checkedAt != nil && visible.isEmpty { Text("表示対象はありません。下の確認状況も参照してください。").foregroundStyle(.secondary) }
                    ForEach(visible) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(key(row)).bold(); Text(row.owner); Spacer(); Text(row.availability.title).font(.caption).foregroundStyle(row.availability == .enabled ? Color.green : .secondary) }
                            Text(row.action).textSelection(.enabled)
                            if candidates.contains(row.id) { Label("競合候補", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange) }
                            Text("\(row.global ? "Mac全体" : "アプリ内") ／ \(row.source)").font(.caption).foregroundStyle(.secondary)
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                    }
                    DisclosureGroup("確認状況・未確認のアプリ") {
                        VStack(alignment: .leading, spacing: 5) { ForEach(Array(model.coverage.enumerated()), id: \.offset) { _, line in Text(line).font(.caption) } }
                    }
                }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("有効状態は確認時点。アプリ内のキーはそのアプリで使用します。実際のキー動作は未確認です。").font(.caption).foregroundStyle(.secondary)
        }.padding(10).controlSize(.regular)
            .background(ExpandableToolWindowSizing(expanded: expanded, compactSize: NSSize(width: 460, height: 560)))
            .frame(minWidth: expanded ? 800 : 440, idealWidth: expanded ? 1100 : 460, minHeight: expanded ? 600 : 480, idealHeight: expanded ? 850 : 560)
    }
}
