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
            let screen = VisibleWindows.activeScreen()
            if let screen {
                VisibleWindows.raiseOnScreen(pid: app.pid, screen: screen)
            }
            running.unhide()
            running.activate()
            if let screen {
                DispatchQueue.main.async {
                    VisibleWindows.raiseOnScreen(pid: app.pid, screen: screen)
                }
            }
        }
        DestinationCache.shared.onChange = { [weak self] in
            self?.buildStatusItem()
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
        DestinationCache.shared.start()
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
        menu.addItem(withTitle: "Jev: \(DestinationCache.shared.status)", action: nil, keyEquivalent: "")
        let pasteKey = NSMenuItem(title: "Paste TypeSafe API key", action: #selector(pasteJevKey), keyEquivalent: "")
        pasteKey.target = self
        menu.addItem(pasteKey)
        if JevKey.value != nil {
            let clearKey = NSMenuItem(title: "Clear TypeSafe API key", action: #selector(clearJevKey), keyEquivalent: "")
            clearKey.target = self
            menu.addItem(clearKey)
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

    @objc private func pasteJevKey() {
        guard let key = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              key.count >= 20
        else { return }
        try? JevKey.save(key)
        DestinationCache.shared.reload()
        buildStatusItem()
    }

    @objc private func clearJevKey() {
        JevKey.clear()
        DestinationCache.shared.reload()
        buildStatusItem()
    }

    @objc private func previewHUD() {
        AppCatalog.shared.refresh()
        hud.show(apps: AppCatalog.shared.ordered())
    }
}
