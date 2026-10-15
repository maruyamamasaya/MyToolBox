// Synthetic data only. Does not use the clipboard or persist user preferences.
import SwiftUI

@main struct RenderJSONWorkspace {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        func check(_ condition: Bool, _ name: String) throws {
            if !condition { throw NSError(domain: "JSONProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
        }
        let model = JSONWorkspaceModel()
        model.text = #"{"a/b~c":[1,true],"name":"MyToolBox"}"#
        await model.refresh()
        model.selection = [0, 1]
        try check(model.pointer == "/a~1b~0c/1", "JSON Pointer escaping")
        model.edit(key: "", kind: "string", value: "変更", add: false)
        try check(model.root?.value(at: [0, 1]) == .string("変更"), "edit")
        await model.refresh()
        model.selection = [0]
        model.edit(key: "", kind: "null", value: "", add: true)
        try check(model.root?.value(at: [0])?.count == 3, "append")
        await model.refresh()
        model.selection = [0, 0]; model.remove()
        try check(model.root?.value(at: [0])?.count == 2, "remove")
        await model.refresh()
        model.selection = []
        let before = model.text
        model.edit(key: "name", kind: "string", value: "duplicate", add: true)
        try check(model.error != nil && model.text == before, "duplicate preserved input")
        model.text = "[1,]"; await model.refresh()
        try check(model.root == nil && model.error != nil, "invalid input clears result")
        model.text = before; await model.refresh()
        try check(model.root != nil && model.error == nil, "recovery")
        let fixture = URL(fileURLWithPath: "build/json-file-check")
        try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories: true)
        let source = fixture.appendingPathComponent("source.json")
        let output = fixture.appendingPathComponent("edited.json")
        try Data(before.utf8).write(to: source)
        let files = JSONWorkspaceModel()
        files.load(source)
        while files.fileBusy { try await Task.sleep(for: .milliseconds(20)) }
        try check(files.text == before && !files.isDirty && files.fileURL == source, "file load baseline")
        files.load(source)
        while files.fileBusy { try await Task.sleep(for: .milliseconds(20)) }
        try check(files.root != nil, "identical file reload preserves tree")
        await files.refresh()
        files.selection = [1]
        files.edit(key: "", kind: "string", value: "ファイル編集", add: false)
        try check(files.isDirty, "file edit is dirty")
        files.save(to: output)
        while files.fileBusy { try await Task.sleep(for: .milliseconds(20)) }
        try check(!files.isDirty && files.fileURL == output, "save baseline")
        try check(try JSONWorkspaceFile.read(output) == files.text, "real saved data")
        try check(try JSONWorkspaceFile.read(source) == before, "original unchanged")
        files.load(fixture.appendingPathComponent("missing.json"))
        while files.fileBusy { try await Task.sleep(for: .milliseconds(20)) }
        try check(files.fileError != nil && !files.isDirty, "read failure keeps baseline")
        files.save(to: fixture.appendingPathComponent("missing/output.json"))
        while files.fileBusy { try await Task.sleep(for: .milliseconds(20)) }
        try check(files.fileError != nil && files.fileURL == output, "save failure keeps file association")
        for theme in VisualTheme.allCases {
            for mode in ["構造ビュー", "整形", "ビルダー"] {
                let size = NSSize(width: 1100, height: 800)
                let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "JSONツール") { JSONWorkspaceView(model: model, mode: mode) })
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
                window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(450)); host.layoutSubtreeIfNeeded()
                func inputEditor(_ view: NSView) -> NSTextView? {
                    if let editor = view as? NSTextView { return editor }
                    return view.subviews.compactMap { inputEditor($0) }.first
                }
                guard let editor = inputEditor(host), let scroll = editor.enclosingScrollView else { fatalError("missing input editor") }
                try check(editor.frame.height >= scroll.contentSize.height && editor.frame.width > 0, "input editor fills viewport")
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { fatalError("bitmap") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let folder = URL(fileURLWithPath: "build/json-preview/\(theme.rawValue)")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("\(mode).png"))
            }
        }
        print("PASS: builder edit/add/remove, Pointer, invalid input recovery, file load/edit/save/reload/failure, 9 theme/mode renders")
    }
}
