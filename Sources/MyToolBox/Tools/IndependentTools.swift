import AppKit

/// Helpers share the existing preferences domain; each tool has a distinct app identity.
enum IndependentTools {
    static let tools = Set(ToolID.allCases)
    // Foundation rejects a suite equal to the current application's own domain.
    static let defaults: UserDefaults = Bundle.main.bundleIdentifier == "local.MyToolBox"
        ? .standard : (UserDefaults(suiteName: "local.MyToolBox") ?? .standard)
    static var current: ToolID? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "MyToolBoxTool") as? String,
              let tool = ToolID(rawValue: id), tools.contains(tool) else { return nil }
        return tool
    }
    static let windowManagerShortcutsKey = "tools.windowManager.shortcuts.v1"
    static let backgroundWindowManagerArgument = "--background-window-manager"
    static func keepsRunningAfterClosing(_ tool: ToolID, defaults: UserDefaults = IndependentTools.defaults) -> Bool {
        tool == .windowManager && defaults.bool(forKey: windowManagerShortcutsKey)
    }
    static func needsBackgroundWindowManager(defaults: UserDefaults = IndependentTools.defaults, isRunning: Bool) -> Bool {
        keepsRunningAfterClosing(.windowManager, defaults: defaults) && !isRunning
    }
    static func startsWithoutWindow(_ tool: ToolID, arguments: [String]) -> Bool {
        tool == .windowManager && arguments.contains(backgroundWindowManagerArgument)
    }
    static func identifier(_ tool: ToolID) -> String { "local.MyToolBox.tool." + tool.rawValue }
    static func running(_ tool: ToolID) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: identifier(tool)).first { !$0.isTerminated }
    }
    @MainActor static func open(_ tool: ToolID, activate: Bool = true, completion: @escaping () -> Void) {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/\(tool.rawValue).app")
        guard FileManager.default.fileExists(atPath: url.path) else {
            let alert = NSAlert(); alert.messageText = "ツールを起動できません"
            alert.informativeText = "同梱アプリがありません。MyToolBoxを再ビルドしてください。"; alert.runModal()
            completion(); return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activate
        if tool == .windowManager && !activate { configuration.arguments = [backgroundWindowManagerArgument] }
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    let alert = NSAlert(); alert.messageText = "ツールを起動できません"
                    alert.informativeText = error.localizedDescription; alert.runModal()
                }
                completion()
            }
        }
    }
}
