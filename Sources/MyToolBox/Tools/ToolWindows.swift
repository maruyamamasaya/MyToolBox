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
        case .businessDays: controller = ToolWindow(title: tool.title, view: BusinessDaysView())
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
        case .comparison:
            let model = ComparisonModel(); controller = ToolWindow(title: tool.title, view: ComparisonView(model: model)); controller.cleanup = { model.stop() }
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
    init<V: View>(title: String, view: V) {
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = title; window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        super.init(window: window); window.delegate = self
        window.setContentSize(hosting.view.fittingSize)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    func windowShouldClose(_ sender: NSWindow) -> Bool { sender.makeFirstResponder(nil); return canClose() }
    func windowWillClose(_ notification: Notification) { stopAudio(); cleanup(); closed() }
}
