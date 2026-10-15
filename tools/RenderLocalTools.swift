// Offscreen UI fixtures; does not request microphone access or play sound.
import SwiftUI
@main struct RenderLocalTools {
    @MainActor static func main() async throws {
        if ProcessInfo.processInfo.arguments.contains("--user-agent-probe") {
            _ = NSApplication.shared
            let model = UserAgentModel()
            for _ in 0..<100 {
                if !model.busy { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            guard !model.busy, !model.userAgent.isEmpty, model.fields.count == 15,
                  model.report.contains(model.userAgent), model.report.contains("MyToolBox 内蔵WebKit") else {
                throw ToolFailure.message("WebKit実取得失敗: \(model.status)")
            }
            print("PASS: local WebKit collected UA and 15 fields; report contains source and UA")
            return
        }
        let selectedTheme = ProcessInfo.processInfo.arguments.dropFirst().first.map { VisualTheme.resolve($0) } ?? .blueCosmos
        let outputDirectory = "evidence/themes/" + selectedTheme.rawValue
        try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
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
        let comparison = ComparisonModel(); comparison.left = "server = production\ntimeout = 30\nregion = Tokyo"; comparison.right = "server = production\ntimeout = 60\nregion = Tokyo\nretry = 3"; comparison.compare()
        let comparedLists = ComparisonModel(); comparedLists.mode = .lists; comparedLists.left = "apple\nbanana\norange\napple"; comparedLists.right = "banana\norange\ngrape"; comparedLists.compare()
        try await Task.sleep(nanoseconds: 500_000_000)
        let codec = TextCodecModel(); codec.input = "日本語のテキスト\nHello"; codec.output = try TextCodec.convert(codec.input, mode: .base64Encode).text
        let inspector = TextTransformModel(cleaner: true); inspector.input = "Hello\u{200B} world\n日本語\u{FFFD}"; inspector.cleanerMode = "文字チェック"; inspector.output = try TextCodec.convert(inspector.input, mode: .inspect).text
        let visual = TextTransformModel(cleaner: true); visual.input = "Hello world\n日本語　\tテスト"; visual.cleanerMode = "可視化"; visual.output = try TextCodec.convert(visual.input, mode: .visualize).text
        let calendarModel = CalendarWorkspaceModel(holidayURL: URL(fileURLWithPath: "Resources/JapaneseHolidays.json"))
        calendarModel.month = BusinessDays.calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        calendarModel.candidates.mode = .multiple
        for day in [15, 20, 23] { calendarModel.candidates.choose(BusinessDays.calendar.date(from: DateComponents(year: 2026, month: 10, day: day))!) }
        calendarModel.candidates.setTime(.init(start: 9, end: 11), for: BusinessDays.calendar.date(from: DateComponents(year: 2026, month: 10, day: 20))!)
        calendarModel.custom = ["2026-10-23": "会社休日"]
        let views: [(String, AnyView, NSSize)] = [
            ("byte-converter", AnyView(TechnicalCalculatorView(tool: .byteConverter)), NSSize(width: 900, height: 850)),
            ("number-base-converter", AnyView(TechnicalCalculatorView(tool: .numberBaseConverter)), NSSize(width: 900, height: 850)),
            ("bandwidth-calculator", AnyView(TechnicalCalculatorView(tool: .bandwidthCalculator)), NSSize(width: 900, height: 850)),
            ("raid-calculator", AnyView(TechnicalCalculatorView(tool: .raidCalculator)), NSSize(width: 900, height: 850)),
            ("sla-calculator", AnyView(TechnicalCalculatorView(tool: .slaCalculator)), NSSize(width: 900, height: 850)),

            ("user-agent", AnyView(UserAgentView()), NSSize(width: 980, height: 1450)),
            ("color-palette", AnyView(ColorPaletteView()), NSSize(width: 1000, height: 1250)),
            ("calendar-candidates", AnyView(CalendarWorkspaceView(model: calendarModel)), NSSize(width: 1080, height: 1060)),
            ("text-codec", AnyView(TextCodecView(model: codec)), NSSize(width: 1000, height: 720)),
            ("text-inspector", AnyView(TextCleanerView(model: inspector)), NSSize(width: 1000, height: 760)),
            ("text-visualizer", AnyView(TextCleanerView(model: visual)), NSSize(width: 1000, height: 760)),
            ("launcher", AnyView(ToolLauncher(openTool: { _ in }, openMonitorSettings: {})), NSSize(width: ToolLauncher.preferredWidth, height: ToolLauncher.preferredHeight)),
            ("business-days", AnyView(BusinessDaysView(model: CalendarWorkspaceModel(holidayURL: URL(fileURLWithPath: "Resources/JapaneseHolidays.json")))), NSSize(width: 820, height: 960)),
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
            ("text-comparison", AnyView(ComparisonView(model: comparison)), NSSize(width: 1100, height: 1000)),
            ("list-comparison", AnyView(ComparisonView(model: comparedLists)), NSSize(width: 1100, height: 900)),
            ("list-converter", AnyView(ClipboardWorkspaceView(table: ClipboardFormatterModel(), list: list, listMode: true)), NSSize(width: 1080, height: 940))
        ]
        for (name, view, size) in views {
            if ProcessInfo.processInfo.arguments.contains("--launcher-only") && name != "launcher" { continue }
            if ProcessInfo.processInfo.arguments.contains("--calculators-only") && !["byte-converter", "number-base-converter", "bandwidth-calculator", "raid-calculator", "sla-calculator"].contains(name) { continue }
            if ProcessInfo.processInfo.arguments.contains("--user-agent-only") && name != "user-agent" { continue }
            let host = NSHostingView(rootView: ThemeRoot(override: selectedTheme, windowTitle: name == "launcher" ? nil : name) { view })
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: selectedTheme == .windows98 ? .aqua : .darkAqua); window.contentView = host
            host.frame = NSRect(origin: .zero, size: size); window.displayIfNeeded()
            try await Task.sleep(nanoseconds: name == "user-agent" ? 2_000_000_000 : 300_000_000); host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("描画失敗") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outputDirectory)/tool-\(name).png"))
            print("Rendered \(name)")
        }
    }
}
