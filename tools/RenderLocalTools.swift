// Offscreen UI fixtures; does not request microphone access or play sound.
import SwiftUI
@main struct RenderLocalTools {
    @MainActor static func main() async throws {
        _ = NSApplication.shared; NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.applicationIconImage = NSImage(contentsOfFile: "Resources/MyToolBox.icns")
        let viewer = CSVModel(editable: false); viewer.rows = [["名前", "地域", "金額"], ["テスト A", "東京", "1200"], ["テスト B", "大阪", "300"]]; viewer.status = "描画検証用サンプル"
        let editor = CSVModel(editable: true); editor.rows = viewer.rows; editor.selectedRow = 1; editor.dirty = true
        let sequential = TextTransformModel(); sequential.input = "東京\n大阪\n福岡"; sequential.options.digits = 3; sequential.options.prefix = "item-"; sequential.update()
        let cleaner = TextTransformModel(cleaner: true); cleaner.input = "会議メモ\n\n\n・\n次回の予定を確認\nHello\u{00a0}world"; cleaner.update()
        let formatter = ClipboardFormatterModel(); formatter.input = "名前\t部署\t番号\n山田\t営業\t1001\n佐藤\t開発\t1002"; formatter.parse()
        let sorter = LineToolModel(); sorter.input = "server10\nserver2\nserver1"; sorter.update()
        let filter = LineToolModel(); filter.mode = .filter; filter.input = "INFO ready\nERROR api\nERROR db"; filter.filter.conditions = [.init(value: "ERROR")]; filter.filter.showNumbers = true; filter.update()
        let duplicates = LineToolModel(); duplicates.mode = .duplicates; duplicates.input = " Apple \napple\nAPPLE\nbanana"; duplicates.duplicates.ignoreCase = true; duplicates.update()
        let replacer = ReplacerModel(); replacer.input = "Apple apple\napple_test"; replacer.options.mode = .replace; replacer.options.query = "apple"; replacer.options.replacement = "orange"; replacer.run()
        let list = ListConverterModel(); list.input = " apple, banana,apple "; list.options.input = .comma; list.options.deduplicate = true; list.options.format = .json; list.update()
        try await Task.sleep(nanoseconds: 500_000_000)
        let views: [(String, AnyView, NSSize)] = [
            ("launcher", AnyView(ToolLauncher(openTool: { _ in }, openMonitorSettings: {})), NSSize(width: 440, height: ToolLauncher.preferredHeight)),
            ("business-days", AnyView(BusinessDaysView(holidayURL: URL(fileURLWithPath: "Resources/JapaneseHolidays.json"))), NSSize(width: 820, height: 960)),
            ("csv-viewer", AnyView(CSVToolView(model: viewer)), NSSize(width: 1000, height: 740)),
            ("csv-editor", AnyView(CSVToolView(model: editor)), NSSize(width: 1000, height: 820)),
            ("audio-check", AnyView(AudioCheckView(model: SpeakerModel())), NSSize(width: 720, height: 640)),
            ("microphone-check", AnyView(MicrophoneCheckView(model: MicrophoneModel())), NSSize(width: 720, height: 780)),
            ("sequential-text", AnyView(SequentialTextView(model: sequential)), NSSize(width: 1000, height: 760)),
            ("clipboard-formatter", AnyView(ClipboardWorkspaceView(table: formatter, list: list)), NSSize(width: 1040, height: 1000)),
            ("text-cleaner", AnyView(TextCleanerView(model: cleaner)), NSSize(width: 1000, height: 720)),
            ("line-sorter", AnyView(LineToolsView(model: sorter)), NSSize(width: 1080, height: 820)),
            ("line-filter", AnyView(LineToolsView(model: filter)), NSSize(width: 1080, height: 860)),
            ("duplicate-finder", AnyView(LineToolsView(model: duplicates)), NSSize(width: 1080, height: 820)),
            ("string-replacer", AnyView(ReplacerView(model: replacer)), NSSize(width: 1100, height: 1050)),
            ("list-converter", AnyView(ClipboardWorkspaceView(table: ClipboardFormatterModel(), list: list, listMode: true)), NSSize(width: 1080, height: 940))
        ]
        for (name, view, size) in views {
            let host = NSHostingView(rootView: view.environment(\.colorScheme, .dark))
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .darkAqua); window.contentView = host
            host.frame = NSRect(origin: .zero, size: size); window.displayIfNeeded()
            try await Task.sleep(nanoseconds: 300_000_000); host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("描画失敗") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "evidence/tool-\(name).png"))
            print("Rendered \(name)")
        }
    }
}
