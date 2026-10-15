// Synthetic integration/render checks. User memos, preferences and clipboard are untouched.
import SwiftUI

@main struct VerifyAddedTools {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw ToolFailure.message("FAIL: " + name) }; print("PASS: " + name)
        }
        let root = URL(fileURLWithPath: "build/added-tools-check/" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let suite = "local.MyToolBox.AddedToolsProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let memoDirectory = root.appendingPathComponent("memo")
        let memo = LocalMemoModel(storageDirectory: memoDirectory)
        try check(memo.writable && memo.notes.count == 1, "memo initial creation")
        memo.update(title: "日本語😀", content: "最終行\n\"quoted\"")
        let reopened = LocalMemoModel(storageDirectory: memoDirectory)
        try check(reopened.selected?.content == "最終行\n\"quoted\"", "memo immediate save/reopen")
        memo.update(title: String(repeating: "字", count: 121))
        try check(memo.selected?.title.count == 120, "memo title limit")
        let prior = memo.archive.notes
        memo.replace([])
        try check(memo.notes.isEmpty && memo.archive.history[0].notes == prior, "memo delete preserves previous generation")
        memo.replace(prior)
        try check(memo.archive.notes == prior, "memo restore")
        let file = memoDirectory.appendingPathComponent("memo-v1.json")
        let saved = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        memo.update(content: "保存失敗中の入力")
        try check(!memo.canClose() && memo.status.contains("保存できません"), "memo write failure blocks close")
        try check(try LocalMemoArchive.importNotes(LocalMemoArchive.backup(memo.archive.notes)).first?.content == "保存失敗中の入力", "memo failed-save data export")
        try FileManager.default.removeItem(at: file)
        try check(memo.save() && memo.canClose(), "memo save failure recovery")
        try Data("broken-json".utf8).write(to: file)
        let broken = LocalMemoModel(storageDirectory: memoDirectory)
        broken.add()
        try check(!broken.writable && (try Data(contentsOf: file)) == Data("broken-json".utf8), "corrupt memo retained")
        try saved.write(to: file); broken.load()
        try check(broken.writable, "memo reload recovery")
        let generator = GeneratorModel()
        generator.generate { Thread.sleep(forTimeInterval: 0.03); return "old" }
        generator.generate { "new" }
        while generator.busy { try await Task.sleep(for: .milliseconds(10)) }
        try check(generator.output == "new", "generation discards cancelled result")
        generator.generate { throw ToolFailure.message("expected") }
        while generator.busy { try await Task.sleep(for: .milliseconds(10)) }
        try check(generator.output.isEmpty && generator.status == "expected", "generation error clears old result")
        let board = TimerBoardModel(defaults: defaults)
        for _ in 0..<13 { board.add() }
        try check(board.timers.count == 12, "timer board maximum")
        board.remove(11); board.duplicate(0); board.move(0, by: 1)
        try check(Set(board.timers.map(\.id)).count == 12, "timer duplicate unique IDs")
        let restoredBoard = TimerBoardModel(defaults: defaults)
        try check(restoredBoard.timers.map(\.id) == board.timers.map(\.id), "timer persisted order")
        restoredBoard.stop()
        let focus = FocusTimerModel(pomodoro: true, defaults: defaults)
        focus.configure(work: 1, rest: 1); focus.toggle()
        focus.tick(Date().addingTimeInterval(61))
        try check(focus.completed == 1 && focus.isBreak, "pomodoro completion and rest")
        let focusRestored = FocusTimerModel(pomodoro: true, defaults: defaults)
        try check(focusRestored.completed == 1, "pomodoro persisted completed count")
        focusRestored.stop()
        let tree = DirectoryTreeModel(defaults: defaults)
        tree.add(child: false, name: "root", folder: true)
        tree.add(child: true, name: "child.txt", folder: false)
        try check(tree.nodes.count == 2 && tree.nodes[1].depth == 1, "tree add child")
        tree.history(redo: false); try check(tree.nodes.count == 1, "tree undo")
        tree.history(redo: true); try check(tree.nodes.count == 2, "tree redo")
        try check(DirectoryTreeModel(defaults: defaults).nodes == tree.nodes, "tree persistence")
        try check(ToolID.testDataGenerator.matches("uuid-generator") && ToolID.portNumberFinder.category == .system, "launcher search and category")
        let sql = SQLWorkspaceModel(); sql.mode = .playground; sql.run()
        while sql.busy { try await Task.sleep(for: .milliseconds(10)) }
        try check(sql.error.isEmpty && !sql.results.isEmpty, "SQL model real SQLite execution")
        let views: [(String, AnyView)] = [
            ("local-memo", AnyView(LocalMemoView(model: broken))),
            ("hash", AnyView(HashGeneratorView(model: GeneratorModel()))),
            ("test-data", AnyView(TestDataGeneratorView(model: GeneratorModel()))),
            ("sentences", AnyView(TestDataGeneratorView(model: GeneratorModel(), initialMode: "文章"))),
            ("dummy-csv", AnyView(TestDataGeneratorView(model: GeneratorModel(), initialMode: "CSV"))),
            ("uuid", AnyView(TestDataGeneratorView(model: GeneratorModel(), initialMode: "UUID"))),
            ("directory", AnyView(DirectoryTreeView(defaults: defaults))),
            ("json", AnyView(JSONWorkspaceView())),
            ("ports", AnyView(NetworkReferenceView(ports: true))), ("http", AnyView(NetworkReferenceView(ports: false))),
            ("time", AnyView(TimeCalculatorView())), ("timer-board", AnyView(TimerBoardView(model: board))),
            ("pomodoro", AnyView(FocusTimerView(model: focus))),
            ("meeting", AnyView(FocusTimerView(model: FocusTimerModel(pomodoro: false, defaults: defaults)))),
            ("random", AnyView(RandomNumberView())), ("cidr", AnyView(CIDRAnalyzerView())), ("dns", AnyView(DNSRecordBuilderView())),
            ("unit", AnyView(EverydayCalculatorView(tool: .unitConverter))), ("percent", AnyView(EverydayCalculatorView(tool: .percentageCalculator))),
            ("calculator", AnyView(EverydayCalculatorView(tool: .simpleCalculator))), ("summary", AnyView(EverydayCalculatorView(tool: .numberCalculator))),
            ("cron", AnyView(CronReaderView())), ("linux", AnyView(LinuxCommandView())), ("chmod", AnyView(ChmodCalculatorView())),
            ("unix", AnyView(UnixTimeConverterView())), ("log", AnyView(LogHighlighterView())),
            ("sql", AnyView(SQLWorkspaceView(model: sql))), ("regex", AnyView(RegexTesterView())), ("regex-builder", AnyView(RegexBuilderView())),
            ("table", AnyView(TableBuilderView())), ("csv-stats", AnyView(CSVStatisticsView(sample: true))),
            ("launcher", AnyView(ToolLauncher(openTool: { _ in }, openMonitorSettings: {})))
        ]
        for theme in VisualTheme.allCases { for (name, view) in views {
            let size = NSSize(width: name == "launcher" ? 440 : 1120, height: name == "launcher" ? ToolLauncher.preferredHeight : 900)
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: name) { view }.defaultAppStorage(defaults))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("render failed: " + name) }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let folder = URL(fileURLWithPath: "build/added-tools-preview/\(theme.rawValue)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(name + ".png"))
            window.close(); print("Rendered \(theme.rawValue)/\(name)")
        } }
        board.stop(); focus.stop(); sql.stop()
    }
}
