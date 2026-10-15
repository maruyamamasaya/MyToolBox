// Interactive, isolated native verification host. Not part of the shipping application.
import SwiftUI

@main struct ManualToolCheck {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = ManualCheckDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor final class ManualCheckDelegate: NSObject, NSApplicationDelegate {
    private var launcher: NSWindow!
    private var active: ToolWindow?
    private let suite = "local.MyToolBox.ManualCheck." + UUID().uuidString
    private lazy var defaults = UserDefaults(suiteName: suite)!
    private let storage = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MyToolBox-ManualCheck-" + UUID().uuidString)
    static let tools: [ToolID] = [.tableBuilder, .jsonWorkspace, .sqlWorkspace, .cidrAnalyzer, .dnsRecordBuilder, .unitConverter, .percentageCalculator, .simpleCalculator, .numberCalculator, .cronReader, .linuxCommands, .chmodCalculator, .directoryTree, .unixTimeConverter, .pomodoroTimer, .timerBoard, .meetingTimer, .timeCalculator, .localMemo, .portNumberFinder, .httpStatusViewer, .randomNumberGenerator, .hashGenerator, .testDataGenerator, .logHighlighter, .regexBuilder, .csvStatistics, .userAgent, .colorPalette, .imageResizer]
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(); let appMenu = NSMenu(); let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
        appMenu.addItem(withTitle: "検証を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); let edit = NSMenu(title: "Edit"); editItem.submenu = edit; menu.addItem(editItem)
        for (title, action, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        NSApp.mainMenu = menu
        let root = VStack(alignment: .leading, spacing: 10) {
            Text("MyToolBox 実機確認").font(.title)
            Text("通常アプリとは別プロセス・別設定・一時メモで確認します。")
            ScrollView { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Self.tools) { tool in Button(tool.title) { self.show(tool) }.frame(maxWidth: .infinity) }
            } }
        }.padding(22).frame(width: 650, height: 650)
        launcher = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 650, height: 650), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        launcher.title = "検証ツール一覧"; launcher.contentView = NSHostingView(rootView: root)
        launcher.isReleasedWhenClosed = false; launcher.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func show(_ tool: ToolID) {
        if let active { ThemeWindowActions.close(active.window); if active.window?.isVisible == true { return } }
        let view: AnyView
        var cleanup: () -> Void = {}
        var canClose: () -> Bool = { true }
        switch tool {
        case .tableBuilder: view = AnyView(TableBuilderView())
        case .jsonWorkspace: view = AnyView(JSONWorkspaceView())
        case .sqlWorkspace:
            let model = SQLWorkspaceModel(); view = AnyView(SQLWorkspaceView(model: model)); cleanup = { model.stop() }
        case .cidrAnalyzer: view = AnyView(CIDRAnalyzerView())
        case .dnsRecordBuilder: view = AnyView(DNSRecordBuilderView())
        case .unitConverter, .percentageCalculator, .simpleCalculator, .numberCalculator: view = AnyView(EverydayCalculatorView(tool: tool))
        case .cronReader: view = AnyView(CronReaderView())
        case .linuxCommands: view = AnyView(LinuxCommandView())
        case .chmodCalculator: view = AnyView(ChmodCalculatorView())
        case .directoryTree: view = AnyView(DirectoryTreeView(defaults: defaults))
        case .unixTimeConverter: view = AnyView(UnixTimeConverterView())
        case .pomodoroTimer, .meetingTimer:
            let model = FocusTimerModel(pomodoro: tool == .pomodoroTimer, defaults: defaults)
            view = AnyView(FocusTimerView(model: model)); cleanup = { model.stop() }
        case .timerBoard:
            let model = TimerBoardModel(defaults: defaults); view = AnyView(TimerBoardView(model: model)); cleanup = { model.stop() }
        case .timeCalculator: view = AnyView(TimeCalculatorView())
        case .localMemo:
            let model = LocalMemoModel(storageDirectory: storage); view = AnyView(LocalMemoView(model: model)); canClose = { model.canClose() }
        case .portNumberFinder, .httpStatusViewer: view = AnyView(NetworkReferenceView(ports: tool == .portNumberFinder))
        case .randomNumberGenerator: view = AnyView(RandomNumberView())
        case .hashGenerator, .testDataGenerator:
            let model = GeneratorModel()
            view = tool == .hashGenerator ? AnyView(HashGeneratorView(model: model)) : AnyView(TestDataGeneratorView(model: model))
            cleanup = { model.clear() }
        case .logHighlighter: view = AnyView(LogHighlighterView())
        case .regexBuilder: view = AnyView(RegexBuilderView())
        case .csvStatistics: view = AnyView(CSVStatisticsView())
        case .userAgent: view = AnyView(UserAgentView())
        case .colorPalette: view = AnyView(ColorPaletteView())
        case .imageResizer: view = AnyView(ImageResizerView(model: ImageResizerModel()))
        default: return
        }
        let window = ToolWindow(title: tool.title, view: view, themeDefaults: defaults)
        window.cleanup = cleanup; window.canClose = canClose
        window.closed = { [weak self] in self?.active = nil; self?.launcher.makeKeyAndOrderFront(nil) }
        active = window; window.window?.center(); window.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationWillTerminate(_ notification: Notification) {
        active?.cleanup(); defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: storage)
    }
}
