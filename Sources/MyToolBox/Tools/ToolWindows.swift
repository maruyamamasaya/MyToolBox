import SwiftUI

@MainActor final class ToolWindows {
    private var windows: [ToolID: ToolWindow] = [:]
    private var sleepObserver: NSObjectProtocol?
    init() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopAudio() }
        }
    }
    func show(_ tool: ToolID) {
        if let existing = windows[tool] { existing.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let controller: ToolWindow
        switch tool {
        case .personalCalendar: controller = ToolWindow(title: tool.title, view: PersonalCalendarView())
        case .sqlWorkspace:
            let model = SQLWorkspaceModel()
            controller = ToolWindow(title: tool.title, view: SQLWorkspaceView(model: model))
            controller.cleanup = { model.stop() }
        case .regexTester: controller = ToolWindow(title: tool.title, view: RegexTesterView())
        case .regexBuilder: controller = ToolWindow(title: tool.title, view: RegexBuilderView())
        case .tableBuilder: controller = ToolWindow(title: tool.title, view: TableBuilderView())
        case .csvStatistics: controller = ToolWindow(title: tool.title, view: CSVStatisticsView())
        case .jsonWorkspace:
            let model = JSONWorkspaceModel()
            controller = ToolWindow(title: tool.title, view: JSONWorkspaceView(model: model))
            controller.canClose = { model.confirmClose() }
        case .logHighlighter: controller = ToolWindow(title: tool.title, view: LogHighlighterView())
        case .unitConverter, .percentageCalculator, .simpleCalculator, .numberCalculator: controller = ToolWindow(title: tool.title, view: EverydayCalculatorView(tool: tool))
        case .cidrAnalyzer: controller = ToolWindow(title: tool.title, view: CIDRAnalyzerView())
        case .dnsRecordBuilder: controller = ToolWindow(title: tool.title, view: DNSRecordBuilderView())
        case .cronReader: controller = ToolWindow(title: tool.title, view: CronReaderView())
        case .linuxCommands: controller = ToolWindow(title: tool.title, view: LinuxCommandView())
        case .chmodCalculator: controller = ToolWindow(title: tool.title, view: ChmodCalculatorView())
        case .directoryTree: controller = ToolWindow(title: tool.title, view: DirectoryTreeView())
        case .unixTimeConverter: controller = ToolWindow(title: tool.title, view: UnixTimeConverterView())
        case .hashGenerator, .testDataGenerator:
            let model = GeneratorModel()
            if tool == .hashGenerator { controller = ToolWindow(title: tool.title, view: HashGeneratorView(model: model)) }
            else { controller = ToolWindow(title: tool.title, view: TestDataGeneratorView(model: model)) }
            controller.cleanup = { model.clear() }
        case .randomNumberGenerator: controller = ToolWindow(title: tool.title, view: RandomNumberView())
        case .portNumberFinder, .httpStatusViewer: controller = ToolWindow(title: tool.title, view: NetworkReferenceView(ports: tool == .portNumberFinder))
        case .localMemo:
            let model = LocalMemoModel(); controller = ToolWindow(title: tool.title, view: LocalMemoView(model: model)); controller.canClose = { model.canClose() }
        case .timeCalculator: controller = ToolWindow(title: tool.title, view: TimeCalculatorView())
        case .timerBoard:
            let model = TimerBoardModel(); controller = ToolWindow(title: tool.title, view: TimerBoardView(model: model)); controller.cleanup = { model.stop() }
        case .pomodoroTimer, .meetingTimer:
            let model = FocusTimerModel(pomodoro: tool == .pomodoroTimer); controller = ToolWindow(title: tool.title, view: FocusTimerView(model: model)); controller.cleanup = { model.stop() }

        case .byteConverter, .numberBaseConverter, .bandwidthCalculator, .raidCalculator, .slaCalculator: controller = ToolWindow(title: tool.title, view: TechnicalCalculatorView(tool: tool))
        case .businessDays: controller = ToolWindow(title: tool.title, view: CalendarWorkspaceView())
        case .csvViewer, .csvEditor:
            let model = CSVModel(editable: tool == .csvEditor)
            controller = ToolWindow(title: tool.title, view: CSVToolView(model: model))
            controller.canClose = { model.confirmClose() }
        case .audioCheck:
            let model = SpeakerModel(); controller = ToolWindow(title: tool.title, view: AudioCheckView(model: model)); controller.stopAudio = { model.stop(); model.status = "停止しました" }
        case .microphoneCheck:
            let model = MicrophoneModel(); controller = ToolWindow(title: tool.title, view: MicrophoneCheckView(model: model)); controller.stopAudio = { model.stop(clear: true); model.status = "停止しました" }
        case .sequentialText, .textCleaner:
            let model = TextTransformModel(cleaner: tool == .textCleaner)
            if tool == .textCleaner { controller = ToolWindow(title: tool.title, view: TextCleanerView(model: model)) }
            else { controller = ToolWindow(title: tool.title, view: SequentialTextView(model: model)) }
            controller.cleanup = { model.stop() }
        case .clipboardFormatter:
            let model = ClipboardFormatterModel(), list = ListConverterModel()
            controller = ToolWindow(title: tool.title, view: ClipboardWorkspaceView(table: model, list: list))
            controller.cleanup = { model.stop(); list.stop() }
        case .lineTools:
            let model = LineToolModel(); controller = ToolWindow(title: tool.title, view: LineToolsView(model: model)); controller.cleanup = { model.stop() }
        case .stringReplacer:
            let model = ReplacerModel(); controller = ToolWindow(title: tool.title, view: ReplacerView(model: model)); controller.cleanup = { model.stop() }
        case .textCodec:
            let model = TextCodecModel(); controller = ToolWindow(title: tool.title, view: TextCodecView(model: model)); controller.cleanup = { model.stop() }
        case .comparison:
            let model = ComparisonModel(); controller = ToolWindow(title: tool.title, view: ComparisonView(model: model)); controller.cleanup = { model.stop() }
        case .imageResizer:
            let model = ImageResizerModel(); controller = ToolWindow(title: tool.title, view: ImageResizerView(model: model)); controller.cleanup = { model.stop() }
        case .userAgent: controller = ToolWindow(title: tool.title, view: UserAgentView())
        case .colorPalette: controller = ToolWindow(title: tool.title, view: ColorPaletteView())
        case .systemMonitor: return
        }
        controller.closed = { [weak self] in self?.windows[tool] = nil }
        windows[tool] = controller
        controller.window?.center(); controller.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func canTerminate() -> Bool {
        for window in windows.values { window.window?.makeFirstResponder(nil); if !window.canClose() { return false } }
        return true
    }
    func stopAudio() { windows.values.forEach { $0.stopAudio() } }
}
@MainActor final class ToolWindow: NSWindowController, NSWindowDelegate {
    var canClose: () -> Bool = { true }
    var stopAudio: () -> Void = {}
    var cleanup: () -> Void = {}
    var closed: () -> Void = {}
    init<V: View>(title: String, view: V, themeDefaults: UserDefaults = .standard) {
        let hosting = NSHostingController(rootView: ThemeRoot(windowTitle: title) { view }.defaultAppStorage(themeDefaults))
        let window = ThemedToolWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.contentViewController = hosting
        window.isReleasedWhenClosed = false
        super.init(window: window); window.delegate = self
        window.setContentSize(hosting.view.fittingSize)
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
