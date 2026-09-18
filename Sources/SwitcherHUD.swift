import AppKit
import ApplicationServices

final class SwitcherHUD {
    private let panel: NSPanel
    private let glass = NSGlassEffectView()
    private let root = NSView()
    private let row = NSView()
    private let nameLabel = NSTextField(labelWithString: "")
    private var cells: [IconCell] = []
    private var apps: [SwitcherApp] = []
    private(set) var selected = 0
    private(set) var isVisible = false

    var onCommit: ((SwitcherApp) -> Void)?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.ignoresMouseEvents = false

        glass.cornerRadius = HUDMetrics.cornerRadius
        glass.style = .regular
        glass.contentView = root
        glass.autoresizingMask = [.width, .height]

        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.alignment = .center
        nameLabel.textColor = .labelColor
        nameLabel.backgroundColor = .clear
        nameLabel.isBezeled = false
        nameLabel.isEditable = false
        nameLabel.lineBreakMode = .byTruncatingTail

        root.addSubview(row)
        root.addSubview(nameLabel)
        panel.contentView = glass
    }

    func show(apps: [SwitcherApp]) {
        guard !apps.isEmpty else { return }
        self.apps = apps
        selected = apps.count > 1 ? 1 : 0
        rebuild()
        layoutOnScreen()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        isVisible = true
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            panel.animator().alphaValue = 1
        }
    }

    func move(_ delta: Int) {
        guard !apps.isEmpty else { return }
        selected = (selected + delta + apps.count) % apps.count
        refreshSelection()
    }

    func commit() {
        guard isVisible, apps.indices.contains(selected) else {
            hide()
            return
        }
        let app = apps[selected]
        hide()
        onCommit?(app)
    }

    func cancel() {
        hide()
    }

    func hide() {
        isVisible = false
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    private func rebuild() {
        cells.forEach { $0.removeFromSuperview() }
        cells = apps.enumerated().map { index, app in
            let cell = IconCell(app: app)
            cell.onPick = { [weak self] in
                self?.selected = index
                self?.commit()
            }
            row.addSubview(cell)
            return cell
        }
        refreshSelection()
    }

    private func layoutOnScreen() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let icon = HUDMetrics.iconSize(count: apps.count, screenWidth: visible.width)
        let size = HUDMetrics.panelSize(count: max(apps.count, 1), icon: icon)
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        glass.frame = NSRect(origin: .zero, size: size)
        root.frame = glass.bounds

        let cell = icon + HUDMetrics.highlightPad * 2
        row.frame = NSRect(
            x: HUDMetrics.padH,
            y: HUDMetrics.padBottom + HUDMetrics.nameHeight + HUDMetrics.nameGap,
            width: size.width - HUDMetrics.padH * 2,
            height: cell
        )
        var x: CGFloat = 0
        for cellView in cells {
            cellView.iconSide = icon
            cellView.frame = NSRect(x: x, y: 0, width: cell, height: cell)
            cellView.layoutIcon()
            x += cell + HUDMetrics.iconSpacing
        }
        nameLabel.frame = NSRect(
            x: HUDMetrics.padH,
            y: HUDMetrics.padBottom,
            width: size.width - HUDMetrics.padH * 2,
            height: HUDMetrics.nameHeight
        )
    }

    private func refreshSelection() {
        for (i, cell) in cells.enumerated() {
            cell.isChosen = i == selected
        }
        nameLabel.stringValue = apps.indices.contains(selected) ? apps[selected].name : ""
    }
}

final class IconCell: NSView {
    var iconSide: CGFloat = HUDMetrics.iconSize
    var onPick: (() -> Void)?
    var isChosen = false {
        didSet { highlight.isHidden = !isChosen }
    }

    private let highlight = NSView()
    private let imageView = NSImageView()

    init(app: SwitcherApp) {
        super.init(frame: .zero)
        wantsLayer = true

        highlight.wantsLayer = true
        highlight.layer?.cornerRadius = HUDMetrics.highlightRadius
        highlight.layer?.cornerCurve = .continuous
        highlight.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
        highlight.isHidden = true

        imageView.image = app.icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true

        addSubview(highlight)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { nil }

    func layoutIcon() {
        highlight.frame = bounds
        imageView.frame = bounds.insetBy(dx: HUDMetrics.highlightPad, dy: HUDMetrics.highlightPad)
    }

    override func mouseDown(with event: NSEvent) {
        onPick?()
    }

    override func viewDidChangeEffectiveAppearance() {
        highlight.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.12).cgColor
    }
}
