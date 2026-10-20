import Foundation
import Carbon

/// Uses the production model/coordinator with a fake OS registration boundary.
/// No NSApplication, foreground windows, real hotkeys, or production defaults.
@MainActor private final class RegistrationPool {
    var owners: [UInt32: UUID] = [:]
}
@MainActor private final class TestRegistration: ToolShortcutRegistration {
    let pool: RegistrationPool
    let id = UUID()
    var key: UInt32?
    var onPress: (() -> Void)?
    init(_ pool: RegistrationPool) { self.pool = pool }
    func unregister() {
        if let key, pool.owners[key] == id { pool.owners[key] = nil }
        key = nil; onPress = nil
    }
    func register(keyCode: UInt32, signature: OSType, onPress: @escaping () -> Void) -> OSStatus {
        guard pool.owners[keyCode] == nil else { return OSStatus(eventHotKeyExistsErr) }
        pool.owners[keyCode] = id; key = keyCode; self.onPress = onPress; return noErr
    }
}
@main struct VerifyIndependentShortcuts {
    @MainActor static func main() throws {
        func check(_ value: Bool, _ label: String) throws {
            if !value { throw NSError(domain: label, code: 1) }; print("PASS: " + label)
        }
        let suite = "local.MyToolBox.IndependentShortcutProbe." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let helperDefaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let pool = RegistrationPool()
        let mainRegistration = TestRegistration(pool), helperRegistration = TestRegistration(pool)
        let memoRegistration = TestRegistration(pool)
        let prefix = "tools.personalCalendar.shortcut"
        defaults.set("J", forKey: prefix + ".key.v1")
        defaults.set(true, forKey: prefix + ".enabled.v1")
        let launcher = ToolShortcutModel(defaults: defaults, registration: mainRegistration)
        let helper = ToolShortcutModel(defaults: helperDefaults, registration: helperRegistration)
        let memo = ToolShortcutModel(defaults: defaults, prefix: "memo", defaultKey: "M", registration: memoRegistration)
        memo.setEnabled(true)
        var running = false
        var launcherOpens = 0, helperOpens = 0
        launcher.onOpen = { launcherOpens += 1 }; helper.onOpen = { helperOpens += 1 }
        let coordinator = IndependentShortcutCoordinator(models: [.personalCalendar: launcher, .localMemo: memo], isRunning: { $0 == .personalCalendar && running })
        coordinator.restore(); mainRegistration.onPress?()
        try check(launcher.enabled && launcher.key == "J" && launcherOpens == 1 && memo.enabled, "saved calendar key restored independently of memo")
        coordinator.beginOpening(.personalCalendar)
        coordinator.restore()
        try check(!launcher.enabled && memo.enabled && defaults.bool(forKey: prefix + ".enabled.v1"), "launch gap releases only calendar and preserves enabled preference")
        running = true; helper.restore(); coordinator.finishedOpening(.personalCalendar)
        helperRegistration.onPress?()
        try check(helper.enabled && !launcher.enabled && helperOpens == 1, "helper receives callback after handoff")
        let restartRegistration = TestRegistration(pool)
        let restarted = ToolShortcutModel(defaults: defaults, registration: restartRegistration)
        var restartedOpens = 0
        restarted.onOpen = { restartedOpens += 1 }
        let restartedCoordinator = IndependentShortcutCoordinator(models: [.personalCalendar: restarted], isRunning: { _ in running })
        restartedCoordinator.restore(); helperRegistration.onPress?()
        try check(!restarted.enabled && helper.enabled && helperOpens == 2, "launcher restart leaves live helper shortcut untouched")
        helper.setKey("Q"); helper.relinquish()
        // Simulate a terminated helper still appearing in the OS running-app list.
        restartedCoordinator.helperDidTerminate(.personalCalendar)
        restartRegistration.onPress?()
        try check(restarted.enabled && restarted.key == "Q" && restartedOpens == 1, "termination restores latest helper key despite stale process listing")
        running = false
        restartedCoordinator.beginOpening(.personalCalendar)
        restartedCoordinator.finishedOpening(.personalCalendar)
        try check(restarted.enabled && restarted.key == "Q", "launch failure returns registration to launcher")
        restartedCoordinator.beginOpening(.personalCalendar)
        running = true; helper.restore(); restartedCoordinator.finishedOpening(.personalCalendar)
        helper.setEnabled(false); helper.relinquish(); running = false
        restartedCoordinator.helperDidTerminate(.personalCalendar)
        try check(!restarted.enabled && !defaults.bool(forKey: prefix + ".enabled.v1"), "explicit helper disable survives return to launcher")
        // Simulate a temporary OS key collision; restoration must not erase user's intent.
        helper.setKey("M"); helper.setEnabled(true)
        try check(!helper.enabled && !helper.error.isEmpty && defaults.bool(forKey: prefix + ".enabled.v1"), "registration conflict retains enabled preference for retry")
        memo.relinquish(); helper.restore()
        try check(helper.enabled && helper.error.isEmpty, "restoration retries saved intent after conflict resolves")
        helper.relinquish(); restarted.relinquish()
        try check(pool.owners.isEmpty, "all simulated registrations released")
        try check(IndependentTools.tools.contains(.personalCalendar) && IndependentTools.tools.contains(.personalCountdown), "both calendar tools use independent routes")
    }
}
