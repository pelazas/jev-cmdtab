import AppKit

@main
enum CmdTabApp {
    static func main() {
        if CommandLine.arguments.contains("--self-check") {
            Ranking.runSelfCheck()
            return
        }
        if CommandLine.arguments.contains("--list") {
            AppCatalog.shared.refresh()
            for app in AppCatalog.shared.ordered() {
                let mark = app.isParked ? "  parked" : ""
                print(app.name + mark)
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
