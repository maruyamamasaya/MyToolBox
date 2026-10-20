import SwiftUI

@main struct VerifyQuickMemo {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        func check(_ value: Bool, _ label: String) throws {
            guard value else { throw ToolFailure.message(label) }; print("PASS: " + label)
        }
        let root = URL(fileURLWithPath: "build/quick-memo-probe/" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = LocalMemoModel(storageDirectory: root)
        try check(model.writable && model.notes.count == 1, "initial memo")
        let first = model.selectedID!
        model.update(content: "最初のメモ")
        model.add()
        let second = model.selectedID!
        let order = model.notes.map(\.id)
        model.selectedID = first; model.update(content: "最初のメモ\n追記")
        try check(model.notes.map(\.id) == order, "typing preserves list order")
        let actions = QuickMemoEditorActions()
        let host = NSHostingView(rootView: ProbeEditor(model: model, actions: actions))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 650, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host; host.frame = NSRect(x: 0, y: 0, width: 650, height: 400)
        window.displayIfNeeded(); host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let textView = actions.textView!
        window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        textView.insertText("\n日本語😀", replacementRange: textView.selectedRange())
        try check(LocalMemoModel(storageDirectory: root).archive.notes.first(where: { $0.id == first })?.content.hasSuffix("日本語😀") == true, "native editor immediate save/reopen")
        try await Task.sleep(for: .milliseconds(100))
        textView.breakUndoCoalescing()
        if let undo = textView.undoManager, undo.groupingLevel > 0 { undo.endUndoGrouping() }
        textView.undoManager?.undo()
        try check(model.selected?.content == "最初のメモ\n追記", "native undo persisted")
        textView.undoManager?.redo()
        try check(model.selected?.content.hasSuffix("日本語😀") == true, "native redo persisted")
        model.selectedID = second
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(100))
        try check(actions.textView?.string == "" && actions.textView?.undoManager?.canUndo != true, "switching notes clears cross-note undo")
        let file = root.appendingPathComponent("memo-v1.json")
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        model.update(content: "保存失敗でも保持")
        try check(!model.canClose() && model.selected?.content == "保存失敗でも保持", "failed save preserves input and blocks close")
        try FileManager.default.removeItem(at: file); try check(model.save(), "retry save recovers")
        try check(ToolID.localMemo.title == "クイックメモ" && ToolID.localMemo.matches("ローカルメモ"), "name and legacy search")
        let shortcutDomain = "local.MyToolBox.shortcut-probe." + UUID().uuidString
        let shortcutDefaults = UserDefaults(suiteName: shortcutDomain)!
        defer { shortcutDefaults.removePersistentDomain(forName: shortcutDomain) }
        let launcher = ToolShortcutModel(defaults: shortcutDefaults, prefix: "probe", defaultKey: "Z", signature: 0x4D545031)
        let helper = ToolShortcutModel(defaults: shortcutDefaults, prefix: "probe", defaultKey: "Z", signature: 0x4D545032)
        defer { launcher.relinquish(); helper.relinquish() }
        launcher.setEnabled(true)
        try check(launcher.enabled, "isolated shortcut registration")
        launcher.relinquish()
        try check(!launcher.enabled && shortcutDefaults.bool(forKey: "probe.enabled.v1"), "shortcut transfer preserves preference")
        helper.restore()
        try check(helper.enabled && helper.error.isEmpty, "helper acquires released shortcut")
        helper.relinquish(); launcher.restore()
        try check(launcher.enabled && launcher.error.isEmpty, "launcher reacquires shortcut after helper exit")
        launcher.relinquish()
        for theme in VisualTheme.allCases {
            let size = NSSize(width: 720, height: 520)
            let view = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "クイックメモ") { LocalMemoView(model: model) })
            let preview = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            preview.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            preview.contentView = view; view.frame = NSRect(origin: .zero, size: size)
            preview.displayIfNeeded(); try await Task.sleep(for: .milliseconds(200)); view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw ToolFailure.message("render") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let folder = URL(fileURLWithPath: "build/quick-memo-preview")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent(theme.rawValue + ".png"))
            print("PASS: render " + theme.rawValue)
        }
        window.close()
    }
}

@MainActor private struct ProbeEditor: View {
    @ObservedObject var model: LocalMemoModel
    var actions: QuickMemoEditorActions
    var body: some View {
        QuickMemoTextEditor(noteID: model.selectedID ?? "", text: model.selected?.content ?? "", writable: model.writable,
            fontSize: 15, wraps: true, foreground: .textColor, background: .textBackgroundColor,
            actions: actions, onChange: { model.update(content: $0) })
    }
}
