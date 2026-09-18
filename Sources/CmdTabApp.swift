import AppKit

@main
enum CmdTabApp {
    static func main() {
        if CommandLine.arguments.contains("--self-check") {
            Ranking.runSelfCheck()
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
