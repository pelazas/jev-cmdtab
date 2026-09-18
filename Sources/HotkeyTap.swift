import AppKit
import Carbon.HIToolbox
import ApplicationServices

final class HotkeyTap {
    private var keyTap: CFMachPort?
    private var mouseTap: CFMachPort?
    private(set) var keysRunning = false
    private var mouseRunning = false
    private let hud: SwitcherHUD

    init(hud: SwitcherHUD) {
        self.hud = hud
    }

    @discardableResult
    func start() -> Bool {
        if keysRunning { return true }
        let keys = installKeyTap(location: .cghidEventTap) || installKeyTap(location: .cgSessionEventTap)
        _ = startMouse()
        return keys
    }

    var interceptsCommandTab: Bool { keysRunning }

    private func startMouse() -> Bool {
        if mouseRunning { return true }
        let mask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
        guard let tap = makeTap(location: .cghidEventTap, mask: mask) ?? makeTap(location: .cgSessionEventTap, mask: mask) else {
            return false
        }
        mouseTap = tap
        mouseRunning = true
        return true
    }

    @discardableResult
    private func installKeyTap(location: CGEventTapLocation) -> Bool {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = makeTap(location: location, mask: mask) else { return false }
        keyTap = tap
        keysRunning = true
        return true
    }

    private func makeTap(location: CGEventTapLocation, mask: CGEventMask) -> CFMachPort? {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: location,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else { return nil }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return tap
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let keyTap { CGEvent.tapEnable(tap: keyTap, enable: true) }
            if let mouseTap { CGEvent.tapEnable(tap: mouseTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if hud.isVisible {
            switch type {
            case .mouseMoved, .leftMouseDragged:
                let point = event.unflippedLocation
                DispatchQueue.main.async { self.hud.hover(at: point) }
                return Unmanaged.passUnretained(event)
            case .leftMouseDown:
                let point = event.unflippedLocation
                DispatchQueue.main.async { self.hud.click(at: point) }
                return nil
            case .leftMouseUp:
                return nil
            default:
                break
            }
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
