import AppKit

final class SwitcherApp {
    let pid: pid_t
    let bundleIdentifier: String?
    let name: String
    let icon: NSImage

    init(running: NSRunningApplication) {
        pid = running.processIdentifier
        bundleIdentifier = running.bundleIdentifier
        name = running.localizedName ?? running.bundleIdentifier ?? "App"
        icon = running.icon ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }
}

final class AppCatalog {
    static let shared = AppCatalog()
    static let selfBundleID = "com.pelazas.jevcmdtab"

    private var mru: [pid_t] = []
    private var cache: [SwitcherApp] = []

    private init() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(activated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(launched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(terminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        if let front = NSWorkspace.shared.frontmostApplication {
            mru = [front.processIdentifier]
        }
        refresh()
    }

    func ordered() -> [SwitcherApp] {
        if cache.isEmpty { refresh() }
        return cache
    }

    func refresh() {
        let running = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular
                && !app.isTerminated
                && app.bundleIdentifier != Self.selfBundleID
        }
        let byPid = Dictionary(uniqueKeysWithValues: running.map { ($0.processIdentifier, SwitcherApp(running: $0)) })
        var seen = Set<pid_t>()
        var result: [SwitcherApp] = []
        for pid in mru {
            if let app = byPid[pid] {
                result.append(app)
                seen.insert(pid)
            }
        }
        for app in running {
            let pid = app.processIdentifier
            if seen.insert(pid).inserted, let item = byPid[pid] {
                result.append(item)
            }
        }
        cache = result
    }

    @objc private func activated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        remember(app.processIdentifier)
        refresh()
    }

    @objc private func launched(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        remember(app.processIdentifier)
        refresh()
    }

    @objc private func terminated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        mru.removeAll { $0 == app.processIdentifier }
        refresh()
    }

    private func remember(_ pid: pid_t) {
        mru.removeAll { $0 == pid }
        mru.insert(pid, at: 0)
    }
}
