import AppKit
import SwiftUI
import ServiceManagement

@main struct MyToolBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appTermination) {
                    Button("MyToolBoxを終了…") { delegate.requestTermination() }
                }
            }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private var toolboxStatus: NSStatusItem!
    private var showingTools = false
    private lazy var toolWindows = ToolWindows()
    private var popover: NSPopover!
    private var store: MonitorStore!
    private var strip: StatusStrip!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Explicit maintenance commands only; ordinary launches never alter login registration.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--enable-monitoring-logs") {
            var preferences = LogPreferences.load(); preferences.enabled = true
            preferences.interval = 10; preferences.retentionDays = 7; preferences.save()
            print("monitoringLogs=enabled interval=10 retentionDays=7")
            exit(0)
        }
        if arguments.contains("--enable-login") || arguments.contains("--login-status") {
            do {
                if arguments.contains("--enable-login") { try SMAppService.mainApp.register() }
                print("loginStatus=\(SMAppService.mainApp.status.rawValue)")
            } catch { fputs("Login registration failed: \(error)\n", stderr); exit(1) }
            exit(0)
        }
        // Maintenance commands must not register hotkeys or change their saved setting.
        _ = toolWindows
        store = MonitorStore()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        strip = StatusStrip(frame: .zero)
        strip.onPress = { [weak self] in self?.togglePopover() }
        status.button?.title = ""
        status.button?.target = self; status.button?.action = #selector(togglePopover)
        status.button?.setAccessibilityLabel("MyToolBox 詳細と設定")
        status.button?.addSubview(strip)
        store.updateStatus = { [weak self] in self?.refreshStrip() }
        refreshStrip()
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 390, height: 620)
        toolboxStatus = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toolboxStatus.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "MyToolBox ツール一覧")
        toolboxStatus.button?.image?.isTemplate = true
        toolboxStatus.button?.toolTip = "MyToolBox — ツール一覧"
        toolboxStatus.button?.setAccessibilityLabel("MyToolBox ツール一覧")
        toolboxStatus.button?.target = self
        toolboxStatus.button?.action = #selector(toggleTools)
    }
    private func refreshStrip() {
        strip.update(store: store)
        status.length = strip.intrinsicContentSize.width
        strip.frame = NSRect(origin: .zero, size: strip.intrinsicContentSize)
    }
    private func present<Content: View>(_ content: Content, size: NSSize, anchor: NSStatusBarButton) {
        if popover.isShown { popover.close() }
        popover.contentViewController = NSHostingController(rootView: ThemeRoot { content })
        popover.contentSize = size
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    private func showMonitor(settings: Bool = false, fromToolbox: Bool = false) {
        guard let button = fromToolbox ? toolboxStatus.button : status.button else { return }
        showingTools = false
        store.selected = settings ? "settings" : "overview"
        store.refreshLoginStatus()
        present(Dashboard(store: store, openTools: { [weak self] in self?.showTools() }), size: NSSize(width: 390, height: 620), anchor: button)
    }
    private func showTools() {
        guard let button = toolboxStatus.button else { return }
        showingTools = true
        present(ToolLauncher(openTool: { [weak self] tool in
            if tool == .systemMonitor { self?.showMonitor(fromToolbox: true) }
            else { self?.popover.close(); self?.toolWindows.show(tool) }
        }, openMonitorSettings: { [weak self] in self?.showMonitor(settings: true, fromToolbox: true) }), size: NSSize(width: ToolLauncher.preferredWidth, height: ToolLauncher.preferredHeight), anchor: button)
    }
    @objc func toggleTools() {
        if popover.isShown && showingTools { popover.performClose(nil) } else { showTools() }
    }
    @objc func togglePopover() {
        if popover.isShown && !showingTools { popover.performClose(nil) } else { showMonitor() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Activation/reopen must not replace a popover the user is operating.
        if !popover.isShown { showTools() }
        return false
    }
    func requestTermination() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MyToolBoxを終了しますか？"
        alert.informativeText = "終了するとシステム監視と定期ログの記録が停止します。画面を閉じるだけなら監視は継続します。"
        alert.addButton(withTitle: "監視を続ける")
        alert.addButton(withTitle: "終了する")
        alert.alertStyle = .warning
        if alert.runModal() == .alertSecondButtonReturn { NSApp.terminate(nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { toolWindows.canTerminate() ? .terminateNow : .terminateCancel }
    func applicationWillTerminate(_ notification: Notification) { toolWindows.stopAudio() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
