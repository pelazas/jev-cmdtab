import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    private var statusItem: NSStatusItem?
    private let hud = SwitcherHUD()
    private var tap: HotkeyTap?
    private var demoTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = nil
        _ = CGRequestListenEventAccess()
        _ = CGRequestPostEventAccess()
        hud.onCommit = { app in
            guard let running = NSRunningApplication(processIdentifier: app.pid) else { return }
            running.unhide()
            running.activate()
        }
        buildStatusItem()

        if CommandLine.arguments.contains("--demo") {
            previewHUD()
            demoTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
                NSApp.terminate(nil)
            }
            return
        }

        let tap = HotkeyTap(hud: hud)
        self.tap = tap
        _ = Accessibility.trusted(prompt: true)
        _ = tap.start()
        buildStatusItem()
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            if self?.tap?.start() == true {
                timer.invalidate()
                self?.buildStatusItem()
            }
        }
    }

    private func buildStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.button?.image = NSImage(
                systemSymbolName: "arrow.left.arrow.right",
                accessibilityDescription: "Jev CmdTab"
            )
        }
        let menu = NSMenu()
        let intercept = tap?.interceptsCommandTab == true
        if intercept {
            menu.addItem(withTitle: "Cmd+Tab intercept is on", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Cmd+Tab steal failed", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let preview = NSMenuItem(title: "Show HUD", action: #selector(previewHUD), keyEquivalent: "")
        preview.target = self
        menu.addItem(preview)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Jev CmdTab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem?.menu = menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        tap?.stop()
        NativeCommandTab.restore()
    }

    @objc private func previewHUD() {
        AppCatalog.shared.refresh()
        hud.show(apps: AppCatalog.shared.ordered())
    }
}
