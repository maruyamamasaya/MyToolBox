import AppKit
import SwiftUI
import ServiceManagement
import Combine

@main struct MyToolBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(after: .appInfo) {
                    if IndependentTools.current == nil {
                        Button("ツール一覧を開く") { delegate.showToolsWindow() }.keyboardShortcut("1")
                        Button("雨雲レーダー") { delegate.toggleRainRadar() }
                    }
                }
                CommandGroup(replacing: .appTermination) {
                    if IndependentTools.current != nil {
                        Button("このツールを終了") { NSApp.terminate(nil) }.keyboardShortcut("q")
                    } else {
                        Button("MyToolBoxを終了…") { delegate.requestTermination() }
                    }
                }
            }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private var toolboxStatus: NSStatusItem!
    private var launcherWindow: ToolWindow?
    private var monitorWindow: ToolWindow?
    private var radarStatus: NSStatusItem!
    private let rainRadar = RainRadarController()
    private let serverMenu = ServerMenuController()
    private var weatherChanges: AnyCancellable?
    private var weatherAgeTimer: Timer?
    private var weatherWakeObserver: NSObjectProtocol?
    private lazy var toolWindows = ToolWindows()
    private var store: MonitorStore!
    private var strip: StatusStrip!
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let tool = IndependentTools.current {
            if IndependentTools.startsWithoutWindow(tool, arguments: ProcessInfo.processInfo.arguments) {
                NSApp.setActivationPolicy(.accessory)
                _ = toolWindows
                if !IndependentTools.keepsRunningAfterClosing(.windowManager) { NSApp.terminate(nil) }
                return
            }
            NSApp.setActivationPolicy(.regular)
            toolWindows.show(tool)
            return
        }
        NSApp.setActivationPolicy(.regular)
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
        strip.onPress = { [weak self] in self?.openSystemMonitor() }
        status.button?.title = ""
        status.button?.target = self; status.button?.action = #selector(openSystemMonitor)
        status.button?.setAccessibilityLabel("MyToolBox システムモニターを開く")
        status.button?.addSubview(strip)
        store.updateStatus = { [weak self] in self?.refreshStrip() }
        refreshStrip()
        toolboxStatus = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toolboxStatus.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "MyToolBox ツール一覧")
        toolboxStatus.button?.image?.isTemplate = true
        toolboxStatus.button?.toolTip = "MyToolBox — ツール一覧"
        toolboxStatus.button?.setAccessibilityLabel("MyToolBox ツール一覧")
        toolboxStatus.button?.target = self
        toolboxStatus.button?.action = #selector(openTools)
        radarStatus = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        radarStatus.button?.image = NSImage(systemSymbolName: "cloud.rain", accessibilityDescription: "気象庁 雨雲レーダー")
        radarStatus.button?.image?.isTemplate = true
        radarStatus.button?.toolTip = "気象庁 — 雨雲レーダー"
        radarStatus.button?.setAccessibilityLabel("気象庁 雨雲レーダー")
        radarStatus.button?.target = self
        radarStatus.button?.action = #selector(toggleRainRadar)
        weatherChanges = rainRadar.weather.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshWeatherStatus() }
        }
        // Recheck age without networking, so old observations disappear even between fetches.
        weatherAgeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshWeatherStatus() }
        }
        weatherWakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rainRadar.weather.refresh(); self?.refreshWeatherStatus() }
        }
        serverMenu.openDetails = { [weak self] in self?.toolWindows.show(.serverManagement) }
        serverMenu.start()
        rainRadar.weather.startAutomaticUpdates()
        refreshWeatherStatus()
        // Login launches stay in the background; ordinary launches open the launcher.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let loginLaunch = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch { showToolsWindow() }
    }
    private func refreshWeatherStatus() {
        if let button = radarStatus.button { radarStatus.length = rainRadar.weather.updateMenuButton(button) }
    }
    private func refreshStrip() {
        strip.update(store: store)
        status.length = strip.intrinsicContentSize.width
        strip.frame = NSRect(origin: .zero, size: strip.intrinsicContentSize)
    }
    func showToolsWindow() {
        guard IndependentTools.current == nil, store != nil else { return }
        rainRadar.close()
        if launcherWindow == nil {
            let controller = ToolWindow(title: "MyToolBox — ツール一覧", view: ToolLauncher(
                openTool: { [weak self] tool in
                    self?.toolWindows.show(tool)
                },
                openMonitorSettings: { [weak self] in self?.showMonitorWindow(settings: true) },
                closeTools: { IndependentTools.closeRunningTools() },
                resizable: true
            ))
            controller.window?.contentMinSize = NSSize(width: ToolLauncher.preferredWidth, height: 480)
            controller.window?.setContentSize(NSSize(width: 780, height: 740))
            controller.window?.center()
            controller.window?.setFrameAutosaveName("ToolLauncherWindow")
            controller.window?.setFrameUsingName("ToolLauncherWindow")
            launcherWindow = controller
        }
        launcherWindow?.window?.deminiaturize(nil)
        launcherWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func showMonitorWindow(settings: Bool = false, preserveSelection: Bool = false) {
        guard store != nil else { return }
        rainRadar.close()
        if !preserveSelection { store.selected = settings ? "settings" : "overview" }
        store.refreshLoginStatus()
        if monitorWindow == nil {
            let controller = ToolWindow(title: "MyToolBox — システムモニター", view: Dashboard(
                store: store, openTools: { [weak self] in self?.showToolsWindow() }, resizable: true
            ))
            controller.window?.contentMinSize = NSSize(width: Dashboard.preferredSize.width, height: 480)
            controller.window?.setContentSize(NSSize(width: 820, height: 740))
            controller.window?.center()
            controller.window?.setFrameAutosaveName("SystemMonitorWindow")
            controller.window?.setFrameUsingName("SystemMonitorWindow")
            monitorWindow = controller
        }
        monitorWindow?.window?.deminiaturize(nil)
        monitorWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func toggleRainRadar() {
        guard let button = radarStatus.button else { return }
        rainRadar.toggle(anchor: button)
    }
    @objc func openTools() {
        showToolsWindow()
    }
    @objc func openSystemMonitor() {
        rainRadar.close()
        toolWindows.show(.systemMonitor)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let tool = IndependentTools.current { toolWindows.show(tool); return false }
        showToolsWindow()
        return false
    }
    func requestTermination() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "MyToolBoxを終了しますか？"
        alert.informativeText = "終了するとシステム監視と定期ログの記録が停止します。画面を閉じるだけなら監視は継続します。起動中の独立ツールは終了せず、そのまま使えます。独立モニターの計測は続きますが、本体の定期ログ記録は停止します。"
        alert.addButton(withTitle: "監視を続ける")
        alert.addButton(withTitle: "終了する")
        alert.alertStyle = .warning
        if alert.runModal() == .alertSecondButtonReturn { NSApp.terminate(nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { toolWindows.canTerminate() ? .terminateNow : .terminateCancel }
    func applicationWillTerminate(_ notification: Notification) {
        serverMenu.stop()
        rainRadar.weather.stopAutomaticUpdates()
        weatherAgeTimer?.invalidate()
        if let weatherWakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(weatherWakeObserver) }
        toolWindows.stopAudio(); if IndependentTools.current != nil { toolWindows.closeAll() } }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
