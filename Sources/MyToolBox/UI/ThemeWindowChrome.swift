import SwiftUI
import AppKit

/// Limit AppKit changes to this host window. Never change application-wide appearance.
struct ThemeWindowBridge: NSViewRepresentable {
    let theme: AppTheme
    let customTitle: Bool
    final class Host: NSView {
        var apply: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if let window { apply?(window) } }
    }
    final class Coordinator { var originalStyle: NSWindow.StyleMask? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> Host { Host() }
    func updateNSView(_ view: Host, context: Context) {
        view.apply = { window in
            window.appearance = NSAppearance(named: theme.classic ? .aqua : .darkAqua)
            window.backgroundColor = NSColor(theme.background)
            guard customTitle else { return }
            if context.coordinator.originalStyle == nil { context.coordinator.originalStyle = window.styleMask }
            window.titleVisibility = theme.classic ? .hidden : .visible
            window.titlebarAppearsTransparent = theme.classic
            if theme.classic { window.styleMask.remove([.titled, .fullSizeContentView]) }
            else if let original = context.coordinator.originalStyle { window.styleMask = original }
            for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] { window.standardWindowButton(kind)?.isHidden = theme.classic }
        }
        if let window = view.window { view.apply?(window) }
    }
}
/// Borderless classic windows have no native close button, so performClose is a no-op.
/// Keep the delegate veto (unsaved CSV / failed memo save) before closing directly.
@MainActor enum ThemeWindowActions {
    static func close(_ window: NSWindow?) {
        guard let window else { return }
        window.makeFirstResponder(nil)
        guard window.delegate?.windowShouldClose?(window) ?? true else { return }
        window.close()
    }
}
struct ClassicTitleBar: View {
    let title: String
    @StateObject private var handle = ClassicWindowHandle()
    var body: some View {
        HStack(spacing: 4) {
            ClassicToolIcon(symbol: "app.window").frame(width: 16, height: 16)
            Text(title).font(.custom("Tahoma", size: 12).bold()).lineLimit(1)
            Spacer()
            action("ウィンドウを最小化", glyph: "_", symbol: .miniaturizeButton) { handle.window?.miniaturize(nil) }
            action("ウィンドウサイズを切替", glyph: "□", symbol: .zoomButton) { handle.window?.zoom(nil) }
            action("ウィンドウを閉じる", glyph: "×", symbol: .closeButton) { ThemeWindowActions.close(handle.window) }
        }.foregroundStyle(.white).padding(.horizontal, 4).frame(height: 24)
            .background(handle.active ? Color(hex: 0x000080) : Color(hex: 0x808080))
            .background(DragRegion(handle: handle))
            .padding(3).background(Color(hex: 0xc0c0c0)).overlay(ClassicBevel())
    }
    private func action(_ label: String, glyph: String, symbol: NSWindow.ButtonType, run: @escaping () -> Void) -> some View {
        Button(action: run) { Text(glyph).font(.system(size: 13, weight: .bold)).foregroundStyle(.black).frame(width: 17, height: 16).background(Color(hex: 0xc0c0c0)).overlay(ClassicBevel()) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}
@MainActor private final class ClassicWindowHandle: ObservableObject {
    weak var window: NSWindow?
    @Published var active = true
    private var observers: [NSObjectProtocol] = []
    func connect(_ window: NSWindow) {
        guard self.window !== window else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        self.window = window; active = window.isKeyWindow
        observers = [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.active = self?.window?.isKeyWindow ?? false }
            }
        }
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
private struct DragRegion: NSViewRepresentable {
    let handle: ClassicWindowHandle
    final class Region: NSView {
        var handle: ClassicWindowHandle?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { Task { @MainActor in self.handle?.connect(window) } }
        }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> Region { let view = Region(); view.handle = handle; return view }
    func updateNSView(_ view: Region, context: Context) { if let window = view.window { Task { @MainActor in handle.connect(window) } } }
}
