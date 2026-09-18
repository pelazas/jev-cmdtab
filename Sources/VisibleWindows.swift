import AppKit
import CoreGraphics

enum VisibleWindows {
    static func ownerPids() -> Set<pid_t> {
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
            if owner == "Finder" && isFinderDesktop(name: name, width: width, height: height, screen: screen) {
                continue
            }
            if let pid = window[kCGWindowOwnerPID as String] as? pid_t {
                pids.insert(pid)
            }
        }
        return pids
    }

    private static func isFinderDesktop(name: String, width: CGFloat, height: CGFloat, screen: NSRect) -> Bool {
        if name == "Desktop" { return true }
        if name.isEmpty && screen.width > 0 && width >= screen.width * 0.9 && height >= screen.height * 0.5 {
            return true
        }
        return false
    }
}
