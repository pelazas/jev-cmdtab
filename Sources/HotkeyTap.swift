import AppKit
import Carbon.HIToolbox
import ApplicationServices

final class HotkeyTap {
    private var tap: CFMachPort?
    private var running = false
    private let hud: SwitcherHUD

    init(hud: SwitcherHUD) {
        self.hud = hud
    }

    @discardableResult
    func start() -> Bool {
        if running { return true }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        running = true
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let cmd = flags.contains(.maskCommand)
        let shift = flags.contains(.maskShift)

        if type == .flagsChanged {
            if hud.isVisible && !cmd {
                DispatchQueue.main.async { self.hud.commit() }
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown && cmd && keyCode == Int64(kVK_Tab) {
            DispatchQueue.main.async {
                if !self.hud.isVisible {
                    self.hud.show(apps: AppCatalog.shared.ordered())
                } else {
                    self.hud.move(shift ? -1 : 1)
                }
            }
            return nil
        }

        if type == .keyUp && cmd && keyCode == Int64(kVK_Tab) {
            return hud.isVisible ? nil : Unmanaged.passUnretained(event)
        }

        if hud.isVisible && type == .keyDown && keyCode == Int64(kVK_Escape) {
            DispatchQueue.main.async { self.hud.cancel() }
            return nil
        }

        if hud.isVisible && type == .keyDown && keyCode == Int64(kVK_LeftArrow) {
            DispatchQueue.main.async { self.hud.move(-1) }
            return nil
        }

        if hud.isVisible && type == .keyDown && keyCode == Int64(kVK_RightArrow) {
            DispatchQueue.main.async { self.hud.move(1) }
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}

enum Accessibility {
    static func trusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
