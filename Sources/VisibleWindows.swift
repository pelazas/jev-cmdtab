import AppKit
import ApplicationServices
import CoreGraphics

enum VisibleWindows {
    static func ownerPids() -> Set<pid_t> {
        if Accessibility.trusted(prompt: false) {
            return axOwnerPids()
        }
        return cgOwnerPids()
    }

    static func reason(for app: NSRunningApplication) -> String {
        if app.isHidden { return "hidden" }
        if app.processIdentifier == NSWorkspace.shared.frontmostApplication?.processIdentifier {
            return "frontmost"
        }
        if ownerPids().contains(app.processIdentifier) { return "window" }
        return "no-window"
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
        let app = AXUIElementCreateApplication(pid)
        var raw: AnyObject?
        let err = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &raw)
        guard err == .success, let windows = raw as? [AXUIElement] else { return false }
        for window in windows {
            var role: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &role)
            if (role as? String) != "AXWindow" { continue }
            var minimized: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
            if (minimized as? Bool) == true { continue }
            var title: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
            if (title as? String) == "Desktop" { continue }
            var sizeVal: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeVal)
            if let ax = sizeVal, CFGetTypeID(ax) == AXValueGetTypeID() {
                var size = CGSize.zero
                AXValueGetValue(ax as! AXValue, .cgSize, &size)
                if size.width < 80 || size.height < 80 { continue }
            }
            return true
        }
        return false
    }

    private static func cgOwnerPids() -> Set<pid_t> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        let screen = NSScreen.main?.frame ?? .zero
        var pids = Set<pid_t>()
        for window in raw {
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            if layer != 0 { continue }
            let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
            if alpha < 0.05 { continue }
            let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            if width < 80 || height < 80 { continue }
            let owner = window[kCGWindowOwnerName as String] as? String ?? ""
            let name = window[kCGWindowName as String] as? String ?? ""
            if owner == "Finder" && (name == "Desktop" || (name.isEmpty && screen.width > 0 && width >= screen.width * 0.9)) {
                continue
            }
            if let pid = window[kCGWindowOwnerPID as String] as? pid_t {
                pids.insert(pid)
            }
        }
        return pids
    }
}
