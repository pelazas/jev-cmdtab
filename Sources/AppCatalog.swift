import AppKit

final class SwitcherApp {
    let pid: pid_t
    let bundleIdentifier: String?
    let name: String
    let icon: NSImage
    let isHidden: Bool
    let hasVisibleWindows: Bool
    let dwell: TimeInterval
    let isFrontmost: Bool
    let onCurrentDisplay: Bool

    var isParked: Bool {
        if isFrontmost { return false }
        return isHidden || !hasVisibleWindows
    }

    init(running: NSRunningApplication, visiblePids: Set<pid_t>, localPids: Set<pid_t>, dwell: TimeInterval, frontmost: pid_t?) {
        pid = running.processIdentifier
        bundleIdentifier = running.bundleIdentifier
        name = running.localizedName ?? running.bundleIdentifier ?? "App"
        icon = running.icon ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
        isHidden = running.isHidden
        hasVisibleWindows = visiblePids.contains(running.processIdentifier)
        self.dwell = dwell
        isFrontmost = running.processIdentifier == frontmost
        onCurrentDisplay = localPids.contains(running.processIdentifier) || isFrontmost
    }
}

final class AppCatalog {
    static let shared = AppCatalog()
    static let selfBundleID = "com.pelazas.jevcmdtab"

    private var mru: [pid_t] = []
    private var cache: [SwitcherApp] = []
    private var dwell: [pid_t: TimeInterval] = [:]
    private var dwellPid: pid_t?
    private var dwellStart: Date?

    private init() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(activated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(launched(_:)), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        nc.addObserver(self, selector: #selector(terminated(_:)), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        if let front = NSWorkspace.shared.frontmostApplication {
            mru = [front.processIdentifier]
            dwellPid = front.processIdentifier
            dwellStart = Date()
        }
        refresh()
    }

    func ordered() -> [SwitcherApp] {
        refresh()
        return cache
    }

    func refresh() {
        creditDwell()
        let running = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular
                && !app.isTerminated
                && app.bundleIdentifier != Self.selfBundleID
        }
        let visible = VisibleWindows.ownerPids()
        let local = VisibleWindows.activeScreen().map { VisibleWindows.ownerPids(on: $0) } ?? []
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let byPid = Dictionary(uniqueKeysWithValues: running.map { app in
            (app.processIdentifier, SwitcherApp(
                running: app,
                visiblePids: visible,
                localPids: local,
                dwell: dwell[app.processIdentifier] ?? 0,
                frontmost: front
            ))
        })
        var seen = Set<pid_t>()
        var mruList: [SwitcherApp] = []
        for pid in mru {
            if let app = byPid[pid] {
                mruList.append(app)
                seen.insert(pid)
            }
        }
        for app in running {
            let pid = app.processIdentifier
            if seen.insert(pid).inserted, let item = byPid[pid] {
                mruList.append(item)
            }
        }
        let parked = mruList.map(\.isParked)
        let localFlags = mruList.map(\.onCurrentDisplay)
        let mruIndex = Array(mruList.indices)
        let dwells = mruList.map(\.dwell)
        cache = Ranking.order(parked: parked, local: localFlags, mru: mruIndex, dwell: dwells).map { mruList[$0] }
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
        dwell[app.processIdentifier] = nil
        if dwellPid == app.processIdentifier {
            dwellPid = nil
            dwellStart = nil
        }
        refresh()
    }

    private func remember(_ pid: pid_t) {
        creditDwell()
        mru.removeAll { $0 == pid }
        mru.insert(pid, at: 0)
        dwellPid = pid
        dwellStart = Date()
    }

    private func creditDwell() {
        let now = Date()
        if let pid = dwellPid, let start = dwellStart {
            dwell[pid, default: 0] += now.timeIntervalSince(start)
        }
        dwellStart = now
    }
}
