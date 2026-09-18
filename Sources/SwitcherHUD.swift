import AppKit

final class SwitcherHUD {
    private let panel: SwitcherPanel
    private let glass = NSGlassEffectView()
    private let root = HUDContentView()
    private let row = NSView()
    private var cells: [IconCell] = []
    private var apps: [SwitcherApp] = []
    private(set) var selected = 0
    private(set) var isVisible = false

    var onCommit: ((SwitcherApp) -> Void)?

    init() {
        panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true

        glass.style = .clear
        glass.tintColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        glass.contentView = root
        glass.autoresizingMask = [.width, .height]

        root.addSubview(row)
        panel.contentView = glass
    }

    func show(apps: [SwitcherApp]) {
        guard !apps.isEmpty else { return }
        self.apps = apps
        selected = apps.count > 1 ? 1 : 0
        rebuild()
        layoutOnScreen()
        panel.appearance = NSApp.effectiveAppearance
        glass.appearance = NSApp.effectiveAppearance
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        isVisible = true
    }

    func move(_ delta: Int) {
        guard !apps.isEmpty else { return }
        select((selected + delta + apps.count) % apps.count)
    }

    func select(_ index: Int) {
        guard apps.indices.contains(index) else { return }
        selected = index
        refreshSelection()
    }

    func hover(at screenPoint: CGPoint) {
        if let i = index(at: screenPoint) { select(i) }
    }

    func click(at screenPoint: CGPoint) {
        if let i = index(at: screenPoint) {
            select(i)
            commit()
        }
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

    func cancel() { hide() }

    func hide() {
        isVisible = false
        panel.orderOut(nil)
    }

    func index(at screenPoint: CGPoint) -> Int? {
        let inWindow = panel.convertPoint(fromScreen: screenPoint)
        let inRoot = root.convert(inWindow, from: nil)
        let inRow = row.convert(inRoot, from: root)
        for (i, cell) in cells.enumerated() {
            if cell.frame.insetBy(dx: -4, dy: -4).contains(inRow) { return i }
        }
        return nil
    }

    private func rebuild() {
        cells.forEach { $0.removeFromSuperview() }
        cells = apps.enumerated().map { index, app in
            let cell = IconCell(app: app)
            cell.onHover = { [weak self] in self?.select(index) }
            cell.onPick = { [weak self] in
                self?.select(index)
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
        glass.cornerRadius = size.height / 2
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
            cellView.frame = NSRect(x: x, y: 0, width: cell, height: cell)
            x += cell + HUDMetrics.iconSpacing
        }
        refreshSelection()
    }

    private func refreshSelection() {
        for (i, cell) in cells.enumerated() {
            cell.isChosen = i == selected
        }
        if apps.indices.contains(selected), selected < cells.count {
            let cell = cells[selected]
            let mid = row.frame.minX + cell.frame.midX
            root.caption = apps[selected].name
            root.captionCenterX = mid
        } else {
            root.caption = ""
        }
        root.needsDisplay = true
    }
}

final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class HUDContentView: NSView {
    var caption = ""
    var captionCenterX: CGFloat = 0

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard !caption.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: HUDMetrics.nameFont,
            .foregroundColor: NSColor.labelColor,
        ]
        let text = caption as NSString
        let size = text.size(withAttributes: attrs)
        var x = captionCenterX - size.width / 2
        x = max(HUDMetrics.padH, min(x, bounds.width - HUDMetrics.padH - size.width))
        text.draw(
            in: NSRect(x: x, y: HUDMetrics.padBottom, width: size.width, height: HUDMetrics.nameHeight),
            withAttributes: attrs
        )
    }
}

final class IconCell: NSView {
    var onPick: (() -> Void)?
    var onHover: (() -> Void)?
    var isChosen = false {
        didSet { if isChosen != oldValue { needsDisplay = true } }
    }

    private let icon: NSImage
    private let parked: Bool

    init(app: SwitcherApp) {
        icon = app.icon
        parked = app.isParked
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        alphaValue = parked ? 0.42 : 1
    }

    required init?(coder: NSCoder) { nil }

    override var isOpaque: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseEntered(with event: NSEvent) { onHover?() }

    override func mouseDown(with event: NSEvent) { onPick?() }

    override func draw(_ dirtyRect: NSRect) {
        if isChosen {
            let plate = NSBezierPath(roundedRect: bounds, xRadius: HUDMetrics.highlightRadius, yRadius: HUDMetrics.highlightRadius)
            plate.flatness = 0.1
            NSColor(calibratedWhite: 0, alpha: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.38 : 0.12).setFill()
            plate.fill()
        }

        let iconRect = bounds.insetBy(dx: HUDMetrics.highlightPad, dy: HUDMetrics.highlightPad)
        let crop = iconRect.width * HUDMetrics.iconCrop
        let drawRect = iconRect.insetBy(dx: -crop, dy: -crop)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: iconRect).addClip()
        icon.draw(in: drawRect)
        NSGraphicsContext.restoreGraphicsState()
    }
}
