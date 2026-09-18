import AppKit

@main
enum CmdTabApp {
    static func main() {
        if CommandLine.arguments.contains("--restore") {
            NativeCommandTab.restore()
            print("ok")
            return
        }
        if CommandLine.arguments.contains("--self-check") {
            Ranking.runSelfCheck()
            return
        }
        if CommandLine.arguments.contains("--tap-probe") {
            let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            let hid = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, _, event, _ in Unmanaged.passUnretained(event) },
                userInfo: nil
            )
            print("hid-tap: \(hid == nil ? "no" : "yes")")
            print("ax: \(Accessibility.trusted(prompt: false) ? "yes" : "no")")
            print("listen: \(CGPreflightListenEventAccess() ? "yes" : "no")")
            print("post: \(CGPreflightPostEventAccess() ? "yes" : "no")")
            return
        }
        if CommandLine.arguments.contains("--list") {
            print("accessibility: \(Accessibility.trusted(prompt: false) ? "yes" : "no")")
            AppCatalog.shared.refresh()
            for app in AppCatalog.shared.ordered() {
                let running = NSRunningApplication(processIdentifier: app.pid)
                let why = running.map { VisibleWindows.reason(for: $0) } ?? "?"
                let mark = app.isParked ? "parked" : "active"
                print("\(app.name)\t\(mark)\t\(why)")
            }
            return
        }

        let ns = NSApplication.shared
        ns.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        AppDelegate.shared = delegate
        ns.delegate = delegate
        ns.run()
    }
}
