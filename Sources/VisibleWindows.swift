import AppKit
import ApplicationServices
import CoreGraphics

enum VisibleWindows {
    static func activeScreen() -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
    }

    static func ownerPids() -> Set<pid_t> {
        if Accessibility.trusted(prompt: false) {
            return axOwnerPids()
        }
        return Set(cgWindows().map(\.pid))
    }

    static func ownerPids(on screen: NSScreen) -> Set<pid_t> {
        let target = quartzFrame(of: screen)
        var pids = Set<pid_t>()
        for window in cgWindows() {
            let hit = window.bounds.intersection(target)
            if hit.width > 40 && hit.height > 40 {
                pids.insert(window.pid)
            }
        }
        return pids
    }

    @discardableResult
    static func raiseOnScreen(pid: pid_t, screen: NSScreen) -> Bool {
        let target = quartzFrame(of: screen)
        guard let wanted = cgWindows()
            .filter({ $0.pid == pid })
            .max(by: { $0.bounds.intersection(target).area < $1.bounds.intersection(target).area }),
              wanted.bounds.intersection(target).area > 0,
              let ax = matchAXWindow(pid: pid, quartzBounds: wanted.bounds)
        else { return false }
        AXUIElementSetAttributeValue(ax, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(ax, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
        return true
    }

    static func reason(for app: NSRunningApplication) -> String {
        if app.isHidden { return "hidden" }
        if app.processIdentifier == NSWorkspace.shared.frontmostApplication?.processIdentifier {
            return "frontmost"
        }
        if ownerPids().contains(app.processIdentifier) { return "window" }
        return "no-window"
    }

    private struct CgWin {
        let pid: pid_t
        let bounds: CGRect
    }

    private static func cgWindows() -> [CgWin] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let mainWidth = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.width ?? 0
        var list: [CgWin] = []
        for window in raw {
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }
            let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
            if alpha < 0.05 { continue }
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let rect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )
            if rect.width < 80 || rect.height < 80 { continue }
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            let name = window[kCGWindowName as String] as? String ?? ""
            if owner == "Finder" && (name == "Desktop" || (name.isEmpty && mainWidth > 0 && rect.width >= mainWidth * 0.9)) {
                continue
            }
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t else { continue }
            list.append(CgWin(pid: pid, bounds: rect))
        }
        return list
    }

    private static func quartzFrame(of screen: NSScreen) -> CGRect {
        let primaryMaxY = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.maxY
            ?? NSScreen.main?.frame.maxY
            ?? 0
        let f = screen.frame
        return CGRect(x: f.origin.x, y: primaryMaxY - f.maxY, width: f.width, height: f.height)
    }

    private static func axOwnerPids() -> Set<pid_t> {
        var pids = Set<pid_t>()
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if axHasUserWindow(pid: app.processIdentifier) {
                pids.insert(app.processIdentifier)
            }
        }
        return pids
    }

    private static func axHasUserWindow(pid: pid_t) -> Bool {
        axWindows(pid: pid).contains { isUserAXWindow($0) }
    }

    private static func axWindows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var raw: AnyObject?
        let err = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw)
        guard err == .success, let windows = raw as? [AXUIElement] else { return [] }
        return windows
    }

    private static func isUserAXWindow(_ window: AXUIElement) -> Bool {
        var role: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role)
        if (role as? String) != "AXWindow" { return false }
        var minimized: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
        if (minimized as? Bool) == true { return false }
        var title: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        if (title as? String) == "Desktop" { return false }
        if let size = axGeometry(window)?.1, size.width < 80 || size.height < 80 { return false }
        return true
    }

    private static func axGeometry(_ window: AXUIElement) -> (CGPoint, CGSize)? {
        var posRaw: AnyObject?
        var sizeRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRaw) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRaw) == .success,
              let posVal = posRaw, CFGetTypeID(posVal) == AXValueGetTypeID(),
              let sizeVal = sizeRaw, CFGetTypeID(sizeVal) == AXValueGetTypeID()
        else { return nil }
        var pos = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        return (pos, size)
    }

    private static func matchAXWindow(pid: pid_t, quartzBounds: CGRect) -> AXUIElement? {
        let primaryMaxY = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.maxY
            ?? NSScreen.main?.frame.maxY
            ?? 0
        let cocoa = CGPoint(x: quartzBounds.origin.x, y: primaryMaxY - quartzBounds.maxY)
        var best: AXUIElement?
        var bestScore = CGFloat.greatestFiniteMagnitude
        for window in axWindows(pid: pid) {
            guard isUserAXWindow(window), let (pos, size) = axGeometry(window) else { continue }
            let sizeScore = abs(size.width - quartzBounds.width) + abs(size.height - quartzBounds.height)
            let quartzScore = abs(pos.x - quartzBounds.origin.x) + abs(pos.y - quartzBounds.origin.y)
            let cocoaBL = abs(pos.x - cocoa.x) + abs(pos.y - cocoa.y)
            let cocoaTL = abs(pos.x - cocoa.x) + abs(pos.y - (cocoa.y + quartzBounds.height))
            let score = sizeScore + min(quartzScore, cocoaBL, cocoaTL)
            if score < bestScore {
                bestScore = score
                best = window
            }
        }
        return best
    }
}

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
