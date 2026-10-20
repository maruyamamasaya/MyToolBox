// Real routing and window lifecycle with launch/presentation/exit boundaries injected.
// No LaunchServices, hotkeys, audio, microphone, security probes or production defaults.
import SwiftUI

@main struct VerifyAllIndependentTools {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let suite = "local.MyToolBox.AllIndependentProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw ToolFailure.message("FAIL: " + name) }
            print("PASS: " + name)
        }
        var launches: [ToolID] = []
        let parent = ToolWindows(startServices: false, currentTool: nil, defaults: defaults,
                                 launch: { tool, done in launches.append(tool); done() },
                                 present: { _ in fatalError("parent must not own a tool window") })
        try check(launches.isEmpty, "idle parent does not launch any tool")
        try check(IndependentTools.tools == Set(ToolID.allCases), "every catalog tool has an independent route")
        try check(Set(ToolID.allCases.map(IndependentTools.identifier)).count == ToolID.allCases.count, "all helper identities are unique")
        for tool in ToolID.allCases {
            parent.show(tool)
            try check(launches.last == tool, "parent routes " + tool.rawValue + " to helper")
        }
        try check(launches.count == ToolID.allCases.count, "one launch request per user selection")
        let restarted = ToolWindows(startServices: false, currentTool: nil, defaults: defaults,
                                    launch: { _, _ in fatalError("parent restart must not open tools") })
        try check(restarted.canTerminate(), "restarted parent owns no helper windows or close guards")
        try check(parent.canTerminate(), "parent shutdown does not ask helpers to close")
        var presented: ToolWindow?
        var exits: [Bool] = []
        let helper = ToolWindows(startServices: false, currentTool: .simpleCalculator, defaults: defaults,
                                 launch: { _, _ in fatalError("helper must not launch another app") },
                                 present: { presented = $0 }, finishHelper: { exits.append($0) })
        helper.show(.sqlWorkspace)
        try check(presented == nil, "helper cannot open a different tool inside its process")
        helper.show(.simpleCalculator)
        guard let window = presented, let native = window.window else { throw ToolFailure.message("missing offscreen tool window") }
        try check(!native.isVisible, "real calculator window is constructed without desktop presentation")
        var allow = false, cleanup = 0
        window.canClose = { allow }; window.cleanup = { cleanup += 1 }
        try check(!helper.canTerminate() && !window.windowShouldClose(native), "close and quit respect a rejected close guard")
        try check(cleanup == 0 && exits.isEmpty, "rejected close preserves model and helper")
        allow = true
        try check(helper.canTerminate() && window.windowShouldClose(native), "accepted close passes both close and quit guards")
        native.close()
        try check(cleanup == 1 && exits == [false], "ordinary tool close cleans up once and requests process exit")
        try check(helper.canTerminate(), "closed helper releases its window")
        defaults.set(true, forKey: IndependentTools.windowManagerShortcutsKey)
        for tool in ToolID.allCases {
            try check(IndependentTools.keepsRunningAfterClosing(tool, defaults: defaults) == (tool == .windowManager), "close residency policy " + tool.rawValue)
        }
        defaults.set(false, forKey: IndependentTools.windowManagerShortcutsKey)
        try check(!IndependentTools.keepsRunningAfterClosing(.windowManager, defaults: defaults), "disabled window manager exits after close")
        let tree = DirectoryTreeModel(defaults: defaults)
        tree.add(child: false, name: "継続中のツリー", folder: true)
        let reloadedTree = DirectoryTreeModel(defaults: defaults)
        try check(reloadedTree.nodes.first?.name == "継続中のツリー", "directory tree uses injected shared preference domain")
        var preferences = Preferences(); preferences.fahrenheit = true; preferences.save(to: defaults)
        var logging = LogPreferences(); logging.enabled = true; logging.save(to: defaults)
        let monitor = MonitorStore(defaults: defaults, managesBackgroundServices: false, startsAutomatically: false)
        try check(monitor.preferences.fahrenheit && monitor.logPreferences.enabled, "independent monitor inherits existing display and log preferences")
        monitor.refreshLoginStatus(); monitor.setLogin(true); monitor.setLogin(false)
        try check(monitor.loginStatus == "本体で管理" && monitor.loginError == nil, "independent monitor never registers itself as login item")
        monitor.preferences.binaryUnits = false
        try check(!Preferences.load(from: defaults).binaryUnits, "monitor display preference edits retain shared domain")
        monitor.logPreferences.enabled = false
        try check(LogPreferences.load(from: defaults).enabled, "independent monitor cannot overwrite parent log preferences")
        let parentMonitor = MonitorStore(defaults: defaults, managesBackgroundServices: true, startsAutomatically: false)
        try check(parentMonitor.managesBackgroundServices && !monitor.managesBackgroundServices, "only parent monitor owns periodic logging")
        parentMonitor.logPreferences.enabled = false
        try check(!LogPreferences.load(from: defaults).enabled, "parent retains log preference management")
        let directory = URL(fileURLWithPath: "build/all-independent-preview", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for theme in VisualTheme.allCases {
            for selection in ["overview", "settings"] {
                monitor.selected = selection
                let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "システムモニター") {
                    Dashboard(store: monitor, resizable: true)
                }.defaultAppStorage(defaults))
                let size = NSSize(width: 820, height: 900)
                let renderWindow = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                renderWindow.isReleasedWhenClosed = false
                renderWindow.contentView = host; host.frame = NSRect(origin: .zero, size: size)
                renderWindow.displayIfNeeded()
                try await Task.sleep(for: .milliseconds(100))
                host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw ToolFailure.message("bitmap unavailable") }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ToolFailure.message("png unavailable") }
                try png.write(to: directory.appendingPathComponent(theme.rawValue + "-" + selection + ".png"))
                try check(!renderWindow.isVisible, "offscreen monitor " + theme.rawValue + " " + selection)
                renderWindow.close()
            }
        }
        monitor.stop(); parentMonitor.stop()
        helper.closeAll(); parent.closeAll(); restarted.closeAll()
        try check(exits == [false] && cleanup == 1, "parent cleanup cannot terminate or clean up a tool twice")
    }
}
