import SwiftUI

@MainActor final class ToolWindows {
    private var windows: [ToolID: ToolWindow] = [:]
    private var sleepObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var shortcuts: IndependentShortcutCoordinator?
    private var shortcutModels: [ToolID: ToolShortcutModel] {
        [.localMemo: .memo, .personalCalendar: .calendar]
    }
    private let currentTool: ToolID?
    private let launch: @MainActor (ToolID, @escaping () -> Void) -> Void
    private let present: @MainActor (ToolWindow) -> Void
    private let finishHelper: @MainActor (Bool) -> Void
    private let defaults: UserDefaults
    init(startServices: Bool = true, currentTool: ToolID? = IndependentTools.current,
         defaults: UserDefaults = IndependentTools.defaults,
         launch: @escaping @MainActor (ToolID, @escaping () -> Void) -> Void = { IndependentTools.open($0, completion: $1) },
         present: @escaping @MainActor (ToolWindow) -> Void = { controller in
             if IndependentTools.current != nil { NSApp.setActivationPolicy(.regular) }
             if controller.initiallyMaximized { controller.maximizeToVisibleScreen() } else { controller.window?.center() }
             controller.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
         },
         finishHelper: @escaping @MainActor (Bool) -> Void = { keepRunning in
             if keepRunning { NSApp.setActivationPolicy(.accessory) } else { NSApp.terminate(nil) }
         }) {
        self.currentTool = currentTool; self.defaults = defaults
        self.launch = launch; self.present = present; self.finishHelper = finishHelper
        guard startServices else { return }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopAudio() }
        }
        if let tool = currentTool {
            if tool == .windowManager { _ = WindowManagerModel.shared }
            if let model = shortcutModels[tool] {
                model.onOpen = { [weak self] in self?.show(tool) }
                model.restore()
            }
            return
        }
        if IndependentTools.needsBackgroundWindowManager(isRunning: IndependentTools.running(.windowManager) != nil) {
            IndependentTools.open(.windowManager, activate: false) {}
        }
        let models = shortcutModels
        for (tool, model) in models { model.onOpen = { [weak self] in self?.show(tool) } }
        shortcuts = IndependentShortcutCoordinator(models: models, isRunning: { IndependentTools.running($0) != nil })
        shortcuts?.restore()
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let tool = IndependentTools.tools.first(where: { IndependentTools.identifier($0) == app.bundleIdentifier }) else { return }
            Task { @MainActor in self?.shortcuts?.helperDidTerminate(tool) }
        }
    }
    func show(_ tool: ToolID) {
        if currentTool == nil && IndependentTools.tools.contains(tool) {
            shortcuts?.beginOpening(tool)
            launch(tool) { [weak self] in self?.shortcuts?.finishedOpening(tool) }
            return
        }
        guard currentTool == nil || currentTool == tool else { return }
        if let existing = windows[tool] { existing.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        func makeWindow<V: View>(title: String, view: V) -> ToolWindow {
            ToolWindow(title: title, view: view, themeDefaults: defaults)
        }
        let controller: ToolWindow
        switch tool {
        case .serverManagement: controller = makeWindow(title: tool.title, view: ServerManagementView())
        case .shortcutAudit: controller = makeWindow(title: tool.title, view: ShortcutAuditView())
        case .gitBatch:
            let model = GitBatchModel()
            controller = makeWindow(title: tool.title, view: GitBatchView(model: model))
            controller.canClose = { model.canClose }
        case .windowManager: controller = makeWindow(title: tool.title, view: WindowManagerView())
        case .personalCountdown: controller = makeWindow(title: tool.title, view: PersonalCountdownView())
        case .personalCalendar: controller = makeWindow(title: tool.title, view: PersonalCalendarView())
        case .sqlWorkspace:
            let model = SQLWorkspaceModel()
            controller = makeWindow(title: tool.title, view: SQLWorkspaceView(model: model))
            controller.cleanup = { model.stop() }
        case .regexTester: controller = makeWindow(title: tool.title, view: RegexTesterView())
        case .regexBuilder: controller = makeWindow(title: tool.title, view: RegexBuilderView())
        case .tableBuilder: controller = makeWindow(title: tool.title, view: TableBuilderView())
        case .csvStatistics: controller = makeWindow(title: tool.title, view: CSVStatisticsView())
        case .jsonWorkspace:
            let model = JSONWorkspaceModel()
            controller = makeWindow(title: tool.title, view: JSONWorkspaceView(model: model))
            controller.canClose = { model.confirmClose() }
        case .logHighlighter: controller = makeWindow(title: tool.title, view: LogHighlighterView())
        case .unitConverter, .percentageCalculator, .simpleCalculator, .numberCalculator: controller = makeWindow(title: tool.title, view: EverydayCalculatorView(tool: tool))
        case .cidrAnalyzer: controller = makeWindow(title: tool.title, view: CIDRAnalyzerView())
        case .dnsRecordBuilder: controller = makeWindow(title: tool.title, view: DNSRecordBuilderView())
        case .cronReader: controller = makeWindow(title: tool.title, view: CronReaderView())
        case .linuxCommands: controller = makeWindow(title: tool.title, view: LinuxCommandView())
        case .chmodCalculator: controller = makeWindow(title: tool.title, view: ChmodCalculatorView())
        case .directoryTree: controller = makeWindow(title: tool.title, view: DirectoryTreeView())
        case .unixTimeConverter: controller = makeWindow(title: tool.title, view: UnixTimeConverterView())
        case .hashGenerator, .testDataGenerator:
            let model = GeneratorModel()
            if tool == .hashGenerator { controller = makeWindow(title: tool.title, view: HashGeneratorView(model: model)) }
            else { controller = makeWindow(title: tool.title, view: TestDataGeneratorView(model: model)) }
            controller.cleanup = { model.clear() }
        case .randomNumberGenerator: controller = makeWindow(title: tool.title, view: RandomNumberView())
        case .portNumberFinder, .httpStatusViewer: controller = makeWindow(title: tool.title, view: NetworkReferenceView(ports: tool == .portNumberFinder))
        case .localMemo:
            let model = LocalMemoModel(); controller = makeWindow(title: tool.title, view: LocalMemoView(model: model)); controller.canClose = { model.canClose() }
        case .timeCalculator: controller = makeWindow(title: tool.title, view: TimeCalculatorView())
        case .timerBoard:
            let model = TimerBoardModel(); controller = makeWindow(title: tool.title, view: TimerBoardView(model: model)); controller.cleanup = { model.stop() }
        case .pomodoroTimer, .meetingTimer:
            let model = FocusTimerModel(pomodoro: tool == .pomodoroTimer); controller = makeWindow(title: tool.title, view: FocusTimerView(model: model)); controller.cleanup = { model.stop() }

        case .byteConverter, .numberBaseConverter, .bandwidthCalculator, .raidCalculator, .slaCalculator: controller = makeWindow(title: tool.title, view: TechnicalCalculatorView(tool: tool))
        case .businessDays: controller = makeWindow(title: tool.title, view: CalendarWorkspaceView())
        case .csvViewer, .csvEditor:
            let model = CSVModel(editable: tool == .csvEditor)
            controller = makeWindow(title: tool.title, view: CSVToolView(model: model))
            controller.canClose = { model.confirmClose() }
            controller.initiallyMaximized = true
        case .audioCheck:
            let model = SpeakerModel(); controller = makeWindow(title: tool.title, view: AudioCheckView(model: model)); controller.stopAudio = { model.stop(); model.status = "停止しました" }
        case .microphoneCheck:
            let model = MicrophoneModel(); controller = makeWindow(title: tool.title, view: MicrophoneCheckView(model: model)); controller.stopAudio = { model.stop(clear: true); model.status = "停止しました" }
        case .sequentialText, .textCleaner:
            let model = TextTransformModel(cleaner: tool == .textCleaner)
            if tool == .textCleaner { controller = makeWindow(title: tool.title, view: TextCleanerView(model: model)) }
            else { controller = makeWindow(title: tool.title, view: SequentialTextView(model: model)) }
            controller.cleanup = { model.stop() }
        case .clipboardFormatter:
            let model = ClipboardFormatterModel(), list = ListConverterModel()
            controller = makeWindow(title: tool.title, view: ClipboardWorkspaceView(table: model, list: list))
            controller.cleanup = { model.stop(); list.stop() }
        case .lineTools:
            let model = LineToolModel(); controller = makeWindow(title: tool.title, view: LineToolsView(model: model)); controller.cleanup = { model.stop() }
        case .stringReplacer:
            let model = ReplacerModel(); controller = makeWindow(title: tool.title, view: ReplacerView(model: model)); controller.cleanup = { model.stop() }
        case .textCodec:
            let model = TextCodecModel(); controller = makeWindow(title: tool.title, view: TextCodecView(model: model)); controller.cleanup = { model.stop() }
        case .comparison:
            let model = ComparisonModel(); controller = makeWindow(title: tool.title, view: ComparisonView(model: model)); controller.cleanup = { model.stop() }
        case .videoCompressor:
            let model = VideoCompressorModel(); controller = makeWindow(title: tool.title, view: VideoCompressorView(model: model))
            controller.canClose = { !model.busy }; controller.cleanup = { model.stop() }
        case .imageResizer:
            let model = ImageResizerModel(); controller = makeWindow(title: tool.title, view: ImageResizerView(model: model)); controller.cleanup = { model.stop() }
        case .userAgent: controller = makeWindow(title: tool.title, view: UserAgentView())
        case .colorPalette: controller = makeWindow(title: tool.title, view: ColorPaletteView())
        case .systemMonitor:
            let model = MonitorStore(managesBackgroundServices: false)
            controller = makeWindow(title: tool.title, view: Dashboard(store: model, resizable: true))
            controller.window?.contentMinSize = NSSize(width: Dashboard.preferredSize.width, height: 480)
            controller.window?.setContentSize(NSSize(width: 820, height: 740))
            controller.cleanup = { model.stop() }
        }
        controller.closed = { [weak self] in
            self?.windows[tool] = nil
            if let self, let current = self.currentTool {
                self.finishHelper(IndependentTools.keepsRunningAfterClosing(current, defaults: self.defaults))
            }
        }
        windows[tool] = controller
        present(controller)
    }
    func canTerminate() -> Bool {
        for window in windows.values { window.window?.makeFirstResponder(nil); if !window.canClose() { return false } }
        return true
    }
    func closeAll() { if currentTool == .windowManager { WindowManagerModel.shared.stop() }; Array(windows.values).forEach { $0.closed = {}; $0.window?.close() }; windows.removeAll() }
    func stopAudio() { windows.values.forEach { $0.stopAudio() } }
}
@MainActor final class ToolWindow: NSWindowController, NSWindowDelegate {
    var initiallyMaximized = false
    var canClose: () -> Bool = { true }
    var stopAudio: () -> Void = {}
    var cleanup: () -> Void = {}
    var closed: () -> Void = {}
    init<V: View>(title: String, view: V, themeDefaults: UserDefaults = IndependentTools.defaults) {
        let hosting = NSHostingController(rootView: ThemeRoot(windowTitle: title) { view }.defaultAppStorage(themeDefaults))
        let window = ThemedToolWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        super.init(window: window); window.delegate = self
        window.setContentSize(hosting.view.fittingSize)
    }
    func maximizeToVisibleScreen() {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        window.setFrame(screen.visibleFrame, display: false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.makeFirstResponder(nil); return canClose() }
    func windowWillClose(_ notification: Notification) { stopAudio(); cleanup(); closed() }
}


/// Borderless classic windows still receive keyboard focus and participate in window management.
private final class ThemedToolWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
