import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    private var statusItem: NSStatusItem?
    private let hud = SwitcherHUD()
    private var tap: HotkeyTap?
    private var demoTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        hud.onCommit = { app in
            guard let running = NSRunningApplication(processIdentifier: app.pid) else { return }
            running.unhide()
            running.activate()
        }
        buildStatusItem()

        if CommandLine.arguments.contains("--demo") {
            AppCatalog.shared.refresh()
            hud.show(apps: AppCatalog.shared.ordered())
            demoTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                NSApp.terminate(nil)
            }
            return
        }

        let tap = HotkeyTap(hud: hud)
        self.tap = tap
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard Accessibility.trusted(prompt: false) else { return }
            if self?.tap?.start() == true {
                timer.invalidate()
                self?.buildStatusItem()
            }
        }
        if Accessibility.trusted(prompt: true) {
            _ = tap.start()
            buildStatusItem()
        }
    }

    private func buildStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.button?.image = NSImage(
                systemSymbolName: "arrow.left.arrow.right",
                accessibilityDescription: "CmdTab"
            )
        }
        let menu = NSMenu()
        let ok = Accessibility.trusted(prompt: false)
        menu.addItem(withTitle: ok ? "CmdTab is running" : "Needs Accessibility…", action: nil, keyEquivalent: "")
        if !ok {
            let item = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openPrivacy), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit CmdTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    @objc private func openPrivacy() {
        let url = URL(string: "x-apple.systemsettings:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
