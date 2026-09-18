import Foundation

/// Dock consumes ⌘⇥ / ⌘⇧⇥ in the WindowServer symbolic-hotkey layer, before any app
/// event tap or Carbon hotkey. Same IDs AltTab uses (`CGSSymbolicHotKey`).
enum CGSSymbolicHotKey: Int32 {
    case commandTab = 1
    case commandShiftTab = 2
}

@_silgen_name("CGSSetSymbolicHotKeyEnabled")
@discardableResult
func CGSSetSymbolicHotKeyEnabled(_ hotKey: Int32, _ isEnabled: Bool) -> Int32

enum NativeCommandTab {
    private static var hooked = false
    private static let restoreC: @convention(c) () -> Void = {
        CGSSetSymbolicHotKeyEnabled(CGSSymbolicHotKey.commandTab.rawValue, true)
        CGSSetSymbolicHotKeyEnabled(CGSSymbolicHotKey.commandShiftTab.rawValue, true)
    }

    private static let onSignal: @convention(c) (Int32) -> Void = { _ in
        restoreC()
        exit(0)
    }

    static func steal() {
        CGSSetSymbolicHotKeyEnabled(CGSSymbolicHotKey.commandTab.rawValue, false)
        CGSSetSymbolicHotKeyEnabled(CGSSymbolicHotKey.commandShiftTab.rawValue, false)
        if hooked { return }
        hooked = true
        atexit(restoreC)
        signal(SIGINT, onSignal)
        signal(SIGTERM, onSignal)
    }

    static func restore() {
        restoreC()
    }
}
