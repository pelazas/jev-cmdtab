import AppKit
import Carbon
import ApplicationServices

final class HotkeyTap {
    private var tap: CFMachPort?
    private var running = false
    private var carbonOn = false
    private var askedListen = false
    private var handlerRef: EventHandlerRef?
    private var tabRef: EventHotKeyRef?
    private var shiftTabRef: EventHotKeyRef?
    private let hud: SwitcherHUD

    private static let signature: OSType = 0x4A435442 // 'JCTB'

    init(hud: SwitcherHUD) {
        self.hud = hud
    }

    var interceptsCommandTab: Bool { carbonOn }

    @discardableResult
    func start() -> Bool {
        if running { return true }
        NativeCommandTab.steal()
        carbonOn = registerCarbon()
        if !carbonOn {
            NativeCommandTab.restore()
            return false
        }
        _ = startFlagsTap()
        running = true
        return true
    }

    func stop() {
        if let tabRef { UnregisterEventHotKey(tabRef) }
        if let shiftTabRef { UnregisterEventHotKey(shiftTabRef) }
        tabRef = nil
        shiftTabRef = nil
        if let handlerRef { RemoveEventHandler(handlerRef) }
        handlerRef = nil
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        carbonOn = false
        running = false
        NativeCommandTab.restore()
    }

    private func registerCarbon() -> Bool {
        if tabRef != nil { return true }
        let target = GetApplicationEventTarget()
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(
            target,
            { _, event, userData in
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
                let me = Unmanaged<HotkeyTap>.fromOpaque(userData!).takeUnretainedValue()
                let back = id.id == 2
                DispatchQueue.main.async { me.carbonTab(back: back) }
                return noErr
            },
            1,
            &types,
            userData,
            &handlerRef
        )
        if installed != noErr { return false }

        var tab: EventHotKeyRef?
        let tabStatus = RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(cmdKey),
            EventHotKeyID(signature: Self.signature, id: 1),
            target,
            0,
            &tab
        )
        tabRef = tab

        var shiftTab: EventHotKeyRef?
        let shiftStatus = RegisterEventHotKey(
            UInt32(kVK_Tab),
            UInt32(cmdKey | shiftKey),
            EventHotKeyID(signature: Self.signature, id: 2),
            target,
            0,
            &shiftTab
        )
        shiftTabRef = shiftTab
        return tabStatus == noErr && shiftStatus == noErr
    }

    private func carbonTab(back: Bool) {
        if !hud.isVisible {
            hud.show(apps: AppCatalog.shared.ordered(), holdCommand: true, backward: back)
        } else {
            hud.move(back ? -1 : 1)
        }
    }

    private func startFlagsTap() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)
            | (1 << CGEventType.mouseMoved.rawValue)
            | (1 << CGEventType.leftMouseDragged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) ?? CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon!).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        )
        guard let created else {
            if !askedListen {
                askedListen = true
                _ = CGRequestListenEventAccess()
            }
            return false
        }
        tap = created
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
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
                return hud.isVisible ? nil : Unmanaged.passUnretained(event)
            default:
                break
            }
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let cmd = flags.contains(.maskCommand)

        if type == .flagsChanged {
            if hud.isVisible && hud.dismissOnCommandUp && !cmd {
                DispatchQueue.main.async { self.hud.commit() }
            }
            return Unmanaged.passUnretained(event)
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
