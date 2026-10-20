import Carbon

@MainActor protocol WindowManagerShortcutRegistration: AnyObject {
    /// Returns the failed key's index and OS status. Successful registration is all-or-nothing.
    func register(keyCodes: [UInt32], onPress: @escaping (Int) -> Void) -> (Int, OSStatus)?
    func unregister()
}

@MainActor final class CarbonWindowManagerShortcuts: WindowManagerShortcutRegistration {
    private var hotKeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var onPress: ((Int) -> Void)?
    func unregister() {
        hotKeys.forEach { UnregisterEventHotKey($0) }; hotKeys.removeAll()
        if let handler { RemoveEventHandler(handler); self.handler = nil }
        onPress = nil
    }
    func register(keyCodes: [UInt32], onPress: @escaping (Int) -> Void) -> (Int, OSStatus)? {
        unregister(); self.onPress = onPress
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var key = EventHotKeyID()
            guard let event, let context,
                  GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key) == noErr,
                  key.signature == 0x4D544257, key.id > 0 else { return OSStatus(eventNotHandledErr) }
            let registration = Unmanaged<CarbonWindowManagerShortcuts>.fromOpaque(context).takeUnretainedValue()
            let index = Int(key.id) - 1
            Task { @MainActor in registration.onPress?(index) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { unregister(); return (0, installed) }
        for (index, code) in keyCodes.enumerated() {
            var ref: EventHotKeyRef?
            let result = RegisterEventHotKey(code, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4D544257, id: UInt32(index + 1)), GetApplicationEventTarget(), 0, &ref)
            guard result == noErr, let ref else { unregister(); return (index, result) }
            hotKeys.append(ref)
        }
        return nil
    }
}
