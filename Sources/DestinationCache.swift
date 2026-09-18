import AppKit

final class DestinationCache {
    static let shared = DestinationCache()

    private(set) var bundleID: String?
    private(set) var status = "off"
    var onChange: (() -> Void)?

    private var timer: Timer?
    private var lastCount = -1
    private var lastFront: pid_t = 0
    private var generation = 0

    private let noulMin = 0.6
    private let confidenceMin = 0.55

    func start() {
        if timer != nil { return }
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func reload() {
        lastCount = -1
        lastFront = 0
        tick()
    }

    func tick() {
        guard JevKey.value != nil else {
            set(bundleID: nil, status: "off")
            return
        }
        let pasteboard = NSPasteboard.general
        if pasteboard.data(forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) != nil {
            lastCount = pasteboard.changeCount
            set(bundleID: nil, status: "idle")
            return
        }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        if pasteboard.changeCount == lastCount && front == lastFront { return }
        lastCount = pasteboard.changeCount
        lastFront = front
        let clip = String((pasteboard.string(forType: .string) ?? "").prefix(1500))
        if clip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            set(bundleID: nil, status: "idle")
            return
        }
        generation += 1
        let gen = generation
        Task { await self.ask(gen: gen, clip: clip) }
    }

    private func ask(gen: Int, clip: String) async {
        guard let key = JevKey.value else { return }
        let apps = AppCatalog.shared.ordered()
        let front = NSWorkspace.shared.frontmostApplication
        let frontID = front?.bundleIdentifier ?? ""
        let pairs = apps.compactMap { app -> (id: String, name: String)? in
            guard let id = app.bundleIdentifier else { return nil }
            return (id, app.name)
        }
        let result = await JevClient.ask(
            apiKey: key,
            clipboard: clip,
            frontmostName: front?.localizedName ?? "",
            frontmostID: frontID,
            apps: pairs
        )
        await MainActor.run {
            guard gen == self.generation else { return }
            guard let result,
                  result.shouldSwitch >= self.noulMin,
                  result.confidence >= self.confidenceMin,
                  result.destination != frontID,
                  apps.contains(where: { $0.bundleIdentifier == result.destination })
            else {
                self.set(bundleID: nil, status: "idle")
                return
            }
            let name = apps.first { $0.bundleIdentifier == result.destination }?.name ?? result.destination
            self.set(bundleID: result.destination, status: name)
        }
    }

    private func set(bundleID: String?, status: String) {
        if self.bundleID == bundleID && self.status == status { return }
        self.bundleID = bundleID
        self.status = status
        onChange?()
    }
}
