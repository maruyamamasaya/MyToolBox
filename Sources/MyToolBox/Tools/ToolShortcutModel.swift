import SwiftUI
import Carbon

/// The same model can be verified without installing global hotkeys in the user's session.
@MainActor protocol ToolShortcutRegistration: AnyObject {
    func register(keyCode: UInt32, signature: OSType, onPress: @escaping () -> Void) -> OSStatus
    func unregister()
}

@MainActor private final class CarbonToolShortcutRegistration: ToolShortcutRegistration {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var signature: OSType = 0
    private var onPress: (() -> Void)?
    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey); self.hotKey = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
        onPress = nil
    }
    func register(keyCode: UInt32, signature: OSType, onPress: @escaping () -> Void) -> OSStatus {
        unregister()
        self.signature = signature; self.onPress = onPress
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var id = EventHotKeyID()
            guard let event, let context,
                  GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.id == 1 else { return OSStatus(eventNotHandledErr) }
            let registration = Unmanaged<CarbonToolShortcutRegistration>.fromOpaque(context).takeUnretainedValue()
            guard id.signature == registration.signature else { return OSStatus(eventNotHandledErr) }
            Task { @MainActor in registration.onPress?() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { unregister(); return installed }
        let result = RegisterEventHotKey(keyCode, UInt32(controlKey | optionKey | cmdKey),
            EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        if result != noErr { unregister() }
        return result
    }
}

@MainActor final class ToolShortcutModel: ObservableObject {
    static let calendar = ToolShortcutModel()
    static let memo = ToolShortcutModel(prefix: "tools.localMemo.shortcut", defaultKey: "M", signature: 0x4D54424D)
    static let keys: [(name: String, code: UInt32)] = [
        ("A", 0), ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3), ("G", 5),
        ("H", 4), ("I", 34), ("J", 38), ("K", 40), ("L", 37), ("M", 46), ("N", 45),
        ("O", 31), ("P", 35), ("Q", 12), ("R", 15), ("S", 1), ("T", 17), ("U", 32),
        ("V", 9), ("W", 13), ("X", 7), ("Y", 16), ("Z", 6)]
    @Published private(set) var enabled = false
    @Published private(set) var key: String
    @Published private(set) var error = ""
    var onOpen: (() -> Void)?
    private let defaults: UserDefaults
    private let prefix: String
    private let defaultKey: String
    private let signature: OSType
    private let registration: ToolShortcutRegistration
    init(defaults: UserDefaults = IndependentTools.defaults, prefix: String = "tools.personalCalendar.shortcut", defaultKey: String = "K", signature: OSType = 0x4D544243, registration: ToolShortcutRegistration? = nil) {
        self.defaults = defaults; self.prefix = prefix; self.defaultKey = defaultKey; self.signature = signature
        self.registration = registration ?? CarbonToolShortcutRegistration()
        let saved = defaults.string(forKey: prefix + ".key.v1") ?? defaultKey
        key = Self.keys.contains { $0.name == saved } ? saved : defaultKey
    }
    func restore() {
        // A helper may have changed its key since the launcher's model was created.
        defaults.synchronize()
        let saved = defaults.string(forKey: prefix + ".key.v1") ?? defaultKey
        key = Self.keys.contains { $0.name == saved } ? saved : defaultKey
        applyEnabled(defaults.bool(forKey: prefix + ".enabled.v1"))
    }
    func setKey(_ value: String) {
        guard Self.keys.contains(where: { $0.name == value }) else { return }
        key = value
        defaults.set(value, forKey: prefix + ".key.v1")
        applyEnabled(defaults.bool(forKey: prefix + ".enabled.v1"))
    }
    /// Release only this process's registration, leaving the user's intent intact.
    func relinquish() { registration.unregister(); enabled = false }
    func setEnabled(_ value: Bool) {
        defaults.set(value, forKey: prefix + ".enabled.v1")
        applyEnabled(value)
    }
    private func applyEnabled(_ value: Bool) {
        relinquish(); error = ""
        guard value else { return }
        let code = Self.keys.first { $0.name == key }!.code
        let result = registration.register(keyCode: code, signature: signature) { [weak self] in self?.onOpen?() }
        guard result == noErr else {
            error = "⌃⌥⌘\(key)を登録できません。他のキーを選んでください（\(result)）。"; return
        }
        enabled = true
    }
}

/// Own registration only when the helper is absent. Helpers keep theirs across launcher restarts.
@MainActor final class IndependentShortcutCoordinator {
    private let models: [ToolID: ToolShortcutModel]
    private let isRunning: (ToolID) -> Bool
    private var launching: Set<ToolID> = []
    init(models: [ToolID: ToolShortcutModel], isRunning: @escaping (ToolID) -> Bool) {
        self.models = models; self.isRunning = isRunning
    }
    func restore() {
        for (tool, model) in models where !launching.contains(tool) {
            if isRunning(tool) { model.relinquish() } else { model.restore() }
        }
    }
    func beginOpening(_ tool: ToolID) {
        launching.insert(tool); models[tool]?.relinquish()
    }
    func finishedOpening(_ tool: ToolID) { launching.remove(tool); restore() }
    func helperDidTerminate(_ tool: ToolID) {
        // The termination event is authoritative even if NSRunningApplication's list lags.
        if !launching.contains(tool) { models[tool]?.restore() }
    }
}
