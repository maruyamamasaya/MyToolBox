import SwiftUI
import Carbon

/// Only the OS registration boundary is simulated; the production model and lifecycle policy run.
@MainActor private final class TestHotKeyPool {
    var owners: [UInt32: UUID] = [:]
}
@MainActor private final class TestWindowManagerShortcuts: WindowManagerShortcutRegistration {
    let pool: TestHotKeyPool
    let id = UUID()
    var onPress: ((Int) -> Void)?
    var registerCalls = 0
    var forcedFailureIndex: Int?
    init(_ pool: TestHotKeyPool) { self.pool = pool }
    func unregister() {
        pool.owners = pool.owners.filter { $0.value != id }; onPress = nil
    }
    func register(keyCodes: [UInt32], onPress: @escaping (Int) -> Void) -> (Int, OSStatus)? {
        registerCalls += 1; self.onPress = onPress
        for (index, key) in keyCodes.enumerated() {
            // Deliberately leave partial registration to exercise the model's cleanup as well.
            if index == forcedFailureIndex || pool.owners[key] != nil { return (index, OSStatus(eventHotKeyExistsErr)) }
            pool.owners[key] = id
        }
        return nil
    }
}

@main struct RenderWindowManager {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw NSError(domain: name, code: 1) }
            FileHandle.standardOutput.write(Data(("PASS: " + name + "\n").utf8))
        }
        let suite = "local.MyToolBox.WindowManagerProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let pool = TestHotKeyPool(), registration = TestWindowManagerShortcuts(TestHotKeyPool())
        // Use a shared pool for conflict/partial-registration tests below.
        let firstRegistration = TestWindowManagerShortcuts(pool)
        var applied: [WindowLayout] = []
        let model = WindowManagerModel(defaults: defaults, registration: firstRegistration, trustReader: { false }, trackApplications: false, applyOverride: { applied.append($0) })
        defer { model.stop() }
        try check(IndependentTools.tools.contains(.windowManager), "window manager has an independent route")
        try check(IndependentTools.identifier(.windowManager) == "local.MyToolBox.tool.windowManager", "helper has a stable identity distinct from parent AX permission")
        try check(!model.shortcutsEnabled && pool.owners.isEmpty && firstRegistration.registerCalls == 0, "default disabled setting never registers keys")
        try check(!IndependentTools.needsBackgroundWindowManager(defaults: defaults, isRunning: false), "disabled feature does not launch a background helper")
        let expectedCodes: [UInt32] = [123,124,126,125,36,51,8,18,19,20,21,23,12,13,0,1]
        try check(WindowManagerModel.keys.map { $0.1 } == expectedCodes, "all sixteen existing physical key mappings retained")
        model.setShortcuts(true)
        try check(model.shortcutsEnabled && pool.owners.count == 16 && defaults.bool(forKey: IndependentTools.windowManagerShortcutsKey), "enabling registers all keys and preserves existing preference key")
        try check(IndependentTools.keepsRunningAfterClosing(.windowManager, defaults: defaults), "closing the window keeps enabled helper alive")
        try check(!IndependentTools.keepsRunningAfterClosing(.jsonWorkspace, defaults: defaults), "keep-alive does not affect other independent tools")
        try check(IndependentTools.needsBackgroundWindowManager(defaults: defaults, isRunning: false), "enabled saved setting requests background startup when absent")
        let beforeRestart = firstRegistration.registerCalls
        let restartedParentDefaults = UserDefaults(suiteName: suite)!
        try check(!IndependentTools.needsBackgroundWindowManager(defaults: restartedParentDefaults, isRunning: true) && beforeRestart == firstRegistration.registerCalls, "restarted parent policy skips opening a running helper")
        for index in WindowManagerModel.keys.indices { firstRegistration.onPress?(index) }
        try check(applied == WindowManagerModel.keys.map { $0.0 }, "sixteen callbacks reach the owning model after simulated parent restart")
        firstRegistration.onPress?(-1); firstRegistration.onPress?(16)
        try check(applied.count == 16, "out-of-range hotkey IDs are ignored")
        let contenderRegistration = TestWindowManagerShortcuts(pool)
        let contender = WindowManagerModel(defaults: defaults, registration: contenderRegistration, trustReader: { false }, trackApplications: false, applyOverride: { _ in })
        defer { contender.stop() }
        try check(!contender.shortcutsEnabled && contender.shortcutsRequested && pool.owners.count == 16 && defaults.bool(forKey: IndependentTools.windowManagerShortcutsKey), "registration conflict leaves original owner and enabled intent intact")
        try check(contender.status.contains("登録できません"), "registration failure remains visible")
        model.stop()
        try check(pool.owners.isEmpty && defaults.bool(forKey: IndependentTools.windowManagerShortcutsKey), "explicit helper shutdown releases keys without disabling preference")
        contender.restoreShortcuts()
        try check(contender.shortcutsEnabled && pool.owners.count == 16, "new helper can restore saved shortcut state")
        contender.setShortcuts(false)
        try check(pool.owners.isEmpty && !IndependentTools.keepsRunningAfterClosing(.windowManager, defaults: defaults) && !IndependentTools.needsBackgroundWindowManager(defaults: defaults, isRunning: false), "explicit disable releases keys and stops future autostart")
        contenderRegistration.forcedFailureIndex = 7
        contender.setShortcuts(true)
        try check(!contender.shortcutsEnabled && contender.shortcutsRequested && pool.owners.isEmpty && defaults.bool(forKey: IndependentTools.windowManagerShortcutsKey), "partial registration failure rolls back all keys and keeps desired setting")
        contenderRegistration.forcedFailureIndex = nil; contender.restoreShortcuts()
        try check(contender.shortcutsEnabled && pool.owners.count == 16, "conflict resolution allows retry without re-enabling")
        contender.setShortcuts(false)
        try check(IndependentTools.startsWithoutWindow(.windowManager, arguments: [IndependentTools.backgroundWindowManagerArgument]), "autostart argument suppresses helper window")
        try check(!IndependentTools.startsWithoutWindow(.windowManager, arguments: []) && !IndependentTools.startsWithoutWindow(.localMemo, arguments: [IndependentTools.backgroundWindowManagerArgument]), "normal opening and other tools are not hidden")
        func eligible(_ bundle: String?, pid: pid_t = 2, policy: NSApplication.ActivationPolicy = .regular) -> Bool {
            WindowManagerModel.isEligibleTarget(bundleIdentifier: bundle, processIdentifier: pid, ownProcessIdentifier: 1, policy: policy)
        }
        try check(eligible("example.external.app") && eligible(nil), "ordinary external applications remain eligible targets")
        try check(!eligible("local.MyToolBox") && !eligible("local.MyToolBox.tool.localMemo") && !eligible("local.MyToolBox.tool.windowManager"), "parent and all toolbox helpers cannot replace external target")
        try check(!eligible("example.external.app", pid: 1) && !eligible("example.background", policy: .accessory), "self and background apps are excluded")
        var trustReads = 0
        var permissionRequests = 0
        var permissionGranted = false
        let denied = WindowManagerModel(defaults: defaults, registration: registration, trustReader: { trustReads += 1; return permissionGranted }, trustRequester: { permissionRequests += 1; return permissionGranted }, trackApplications: false)
        defer { denied.stop() }
        denied.apply(.left)
        try check(!denied.trusted && denied.targetName == "未選択" && trustReads == 2 && denied.status.contains("独立版「ウィンドウマネージャー」"), "permission-denied path identifies helper without requesting AX access or writing windows")
        try check(permissionRequests == 0, "startup and placement never prompt for permission")
        denied.requestPermission()
        try check(permissionRequests == 1 && !denied.trusted && denied.status.contains("＋で追加"), "explicit permission request explains manual helper registration")
        permissionGranted = true
        denied.refresh()
        try check(denied.trusted && permissionRequests == 1, "recheck reflects grant without another prompt")
        denied.requestPermission()
        try check(denied.trusted && permissionRequests == 2, "request result reflects existing grant")
        permissionGranted = false
        denied.refresh()
        for theme in VisualTheme.allCases {
            let host = NSHostingView(rootView: ThemeRoot(override: theme, windowTitle: "ウィンドウマネージャー") { WindowManagerView(model: denied) }.defaultAppStorage(defaults))
            let size = NSSize(width: 720, height: 690)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: theme == .windows98 ? .aqua : .darkAqua)
            window.contentView = host; host.frame = NSRect(origin: .zero, size: size)
            window.displayIfNeeded(); try await Task.sleep(for: .milliseconds(200)); host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "offscreen render failed", code: 1) }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "PNG encoding failed", code: 1) }
            let folder = URL(fileURLWithPath: "build/window-manager-preview")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appendingPathComponent(theme.rawValue + ".png"))
            print("PASS: offscreen " + theme.rawValue)
        }
        try check(pool.owners.isEmpty && !defaults.bool(forKey: IndependentTools.windowManagerShortcutsKey), "probe leaves no simulated keys or enabled setting behind")
    }
}
