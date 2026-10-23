import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut.
///
/// Carbon's `RegisterEventHotKey` is used deliberately: it is the only hotkey
/// API that works without asking the user for Accessibility permission.
final class GlobalHotKey {

    private static var actions: [UInt32: () -> Void] = [:]
    private static var eventHandler: EventHandlerRef?
    private static var nextID: UInt32 = 1
    private static let signature = OSType(0x414E434C) // 'ANCL'

    private let id: UInt32
    private var reference: EventHotKeyRef?

    /// - Returns: `nil` when another app already owns the shortcut.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        GlobalHotKey.installDispatcher()

        id = GlobalHotKey.nextID
        GlobalHotKey.nextID += 1

        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: GlobalHotKey.signature, id: id),
            GetEventDispatcherTarget(),
            0,
            &reference
        )

        guard status == noErr, let reference else { return nil }
        self.reference = reference
        GlobalHotKey.actions[id] = action
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        GlobalHotKey.actions[id] = nil
    }

    private static func installDispatcher() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var id = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                if let action = GlobalHotKey.actions[id.id] {
                    DispatchQueue.main.async(execute: action)
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandler
        )
    }
}
