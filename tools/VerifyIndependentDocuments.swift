import SwiftUI

/// Real document models and offscreen views; isolated files, no panels or production app launches.
@main struct VerifyIndependentDocuments {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw NSError(domain: name, code: 1) }; print("PASS: " + name)
        }
        func wait(_ condition: () -> Bool) async throws {
            let deadline = ContinuousClock.now + .seconds(10)
            while condition() {
                guard ContinuousClock.now < deadline else { throw NSError(domain: "document operation timeout", code: 1) }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MyToolBox-DocumentProbe-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "local.MyToolBox.DocumentProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for tool: ToolID in [.jsonWorkspace, .csvViewer, .csvEditor] {
            try check(IndependentTools.tools.contains(tool), "independent route " + tool.rawValue)
        }
        try check(IndependentTools.identifier(.csvViewer) != IndependentTools.identifier(.csvEditor), "viewer and editor have separate identities")

        let jsonSource = folder.appendingPathComponent("source.json")
        let jsonOutput = folder.appendingPathComponent("edited.json")
        let originalJSON = #"{"name":"元の文章","precise":9007199254740993}"#
        try Data(originalJSON.utf8).write(to: jsonSource)
        let json = JSONWorkspaceModel()
        json.load(jsonSource); try await wait { json.fileBusy }
        try check(json.text == originalJSON && !json.isDirty && json.fileURL == jsonSource, "JSON load associates clean baseline")
        json.selection = [0]
        let editedValue = "日本語😀\nカンマ,と\"引用符\""
        json.edit(key: "", kind: "string", value: editedValue, add: false)
        let editedJSON = json.text
        try check(json.root?.value(at: [0]) == .string(editedValue) && json.isDirty, "JSON tree edit retains exact Unicode and large number")
        try check(!json.confirmClose(decideDiscard: { false }) && json.text == editedJSON && json.selection == [0], "JSON close cancellation preserves draft and selection")
        var decisions = 0
        json.fileBusy = true
        try check(!json.confirmClose(decideDiscard: { decisions += 1; return true }) && decisions == 0, "JSON refuses close while file operation is active")
        json.fileBusy = false
        json.save(to: jsonOutput); try await wait { json.fileBusy }
        try check(!json.isDirty && json.fileURL == jsonOutput && (try String(contentsOf: jsonOutput, encoding: .utf8)) == editedJSON, "JSON model save writes current draft")
        try check((try String(contentsOf: jsonSource, encoding: .utf8)) == originalJSON, "JSON separate save preserves original source")
        let reopenedJSON = JSONWorkspaceModel()
        reopenedJSON.load(jsonOutput); try await wait { reopenedJSON.fileBusy }
        try check(reopenedJSON.text == editedJSON && reopenedJSON.root == json.root && reopenedJSON.confirmClose(), "JSON saved file reopens without discard prompt")
        json.text = "{\"unfinished\":"
        await json.refresh()
        let invalidDraft = json.text
        try check(json.error != nil && json.isDirty && !json.confirmClose(decideDiscard: { false }), "invalid unfinished JSON draft is protected")
        json.save(to: jsonOutput); try await wait { json.fileBusy }
        try check(json.fileError != nil && json.isDirty && json.text == invalidDraft && json.fileURL == jsonOutput && (try String(contentsOf: jsonOutput, encoding: .utf8)) == editedJSON, "invalid JSON save preserves disk and in-memory draft")
        json.text = editedJSON + " "
        json.save(to: folder); try await wait { json.fileBusy }
        try check(json.fileError != nil && json.isDirty && json.fileURL == jsonOutput, "JSON write failure retains unsaved state and file association")
        json.text = editedJSON; await json.refresh()

        let csvSource = folder.appendingPathComponent("source.csv")
        let csvOutput = folder.appendingPathComponent("edited.csv")
        let originalCSV = "名前,メモ\r\n日本語,元の値\r\n別の行,比較用\r\n"
        try Data(originalCSV.utf8).write(to: csvSource)
        let csv = CSVModel(editable: true)
        csv.read(csvSource); try await wait { csv.busy }
        try check(csv.rows.count == 3 && !csv.dirty && csv.confirmClose(), "CSV editor reads clean source")
        csv.edit(row: 1, column: 1, value: editedValue)
        csv.search = "日本語"; csv.sort(0); csv.selectedRow = 1; csv.selectedColumn = 1
        let editedRows = csv.rows
        try check(!csv.confirmClose(decideDiscard: { false }) && csv.dirty && csv.rows == editedRows && csv.search == "日本語" && csv.sortColumn == 0 && csv.selectedRow == 1, "CSV close cancellation preserves table and editing context")
        csv.busy = true
        try check(!csv.confirmClose(decideDiscard: { decisions += 1; return true }) && decisions == 0, "CSV refuses close during read or parse")
        csv.busy = false
        csv.save(to: csvOutput)
        let savedCSV = try Data(contentsOf: csvOutput)
        let decodedCSV = try CSVDocument.decode(savedCSV).0
        try check(!csv.dirty && csv.confirmClose() && (try CSVDocument.parse(decodedCSV)) == editedRows, "CSV model save preserves quotes commas and embedded newlines")
        try check((try String(contentsOf: csvSource, encoding: .utf8)) == originalCSV, "CSV separate save preserves original source")
        let viewer = CSVModel(editable: false)
        viewer.read(csvOutput); try await wait { viewer.busy }
        try check(viewer.rows == editedRows && !viewer.dirty, "CSV viewer reopens edited file independently")
        viewer.edit(row: 1, column: 1, value: "must not edit")
        viewer.search = "日本語"; viewer.sort(0)
        viewer.input += "\n未解析の入力"
        try check(viewer.rows == editedRows && !viewer.confirmClose(decideDiscard: { false }), "viewer remains read-only while protecting unparsed input")
        csv.edit(row: 1, column: 1, value: "保存できなくても保持")
        csv.save(to: folder)
        try check(csv.dirty && csv.rows[1][1] == "保存できなくても保持" && (try Data(contentsOf: csvOutput)) == savedCSV, "CSV write failure preserves dirty edits and saved output")
        try check(csv.confirmClose(decideDiscard: { true }) && csv.dirty, "explicit discard approval is required without silently mutating draft")
        // Independent sessions have no shared in-memory document model.
        try check(json.text == editedJSON && viewer.rows == editedRows && csv.rows != viewer.rows, "JSON viewer and editor drafts stay separate")

        let previewFolder = URL(fileURLWithPath: "build/independent-document-preview")
        try FileManager.default.createDirectory(at: previewFolder, withIntermediateDirectories: true)
        for theme in VisualTheme.allCases {
            for tool: ToolID in [.jsonWorkspace, .csvViewer, .csvEditor] {
                let size = NSSize(width: tool == .jsonWorkspace ? 1100 : 1160, height: 820)
                let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: tool.title) {
                    if tool == .jsonWorkspace { JSONWorkspaceView(model: json) }
                    else { CSVToolView(model: tool == .csvViewer ? viewer : csv) }
                }.defaultAppStorage(defaults))
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
                window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(250)); host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "offscreen render failed", code: 1) }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw NSError(domain: "PNG encoding failed", code: 1) }
                try png.write(to: previewFolder.appendingPathComponent(tool.rawValue + "-" + theme.rawValue + ".png"))
                print("PASS: offscreen " + tool.rawValue + " / " + theme.rawValue)
            }
        }
    }
}
