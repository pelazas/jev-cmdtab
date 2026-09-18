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
    private(set) var dismissOnCommandUp = false
    private var holdTimer: Timer?

    var onCommit: ((SwitcherApp) -> Void)?

    init() {
        panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true

        glass.style = .clear
        glass.tintColor = nil
        glass.autoresizingMask = [.width, .height]
        glass.contentView = root
        root.addSubview(row)
        panel.contentView = glass
        crystalize(glass)
    }

    private func crystalize(_ glass: NSGlassEffectView) {
        glass.style = .clear
        glass.tintColor = nil
        glass.setValue(1, forKey: "_contentLensing")
        glass.setValue(1, forKey: "_interactionState")
        glass.setValue(0, forKey: "_subduedState")
        glass.setValue(0, forKey: "_scrimState")
    }

    func show(apps: [SwitcherApp], holdCommand: Bool = false, backward: Bool = false) {
        guard !apps.isEmpty else { return }
        self.apps = apps
        if backward, apps.count > 1 {
            selected = apps.count - 1
        } else {
            selected = apps.count > 1 ? 1 : 0
        }
        dismissOnCommandUp = holdCommand
        rebuild()
        layoutOnScreen()
        panel.appearance = NSApp.effectiveAppearance
        glass.appearance = NSApp.effectiveAppearance
        crystalize(glass)
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        isVisible = true
        watchCommandHold()
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
        holdTimer?.invalidate()
        holdTimer = nil
        isVisible = false
        dismissOnCommandUp = false
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
        glass.cornerRadius = HUDMetrics.barRadius
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

    private func watchCommandHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        guard dismissOnCommandUp else { return }
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self, self.isVisible, self.dismissOnCommandUp else { return }
            if !CGEventSource.flagsState(.hidSystemState).contains(.maskCommand) {
                self.commit()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
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
    override var canBecomeKey: Bool { true }
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
            in: NSRect(x: x, y: HUDMetrics.padBottom + HUDMetrics.nameLift, width: size.width, height: HUDMetrics.nameHeight),
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

    init(app: SwitcherApp) {
        icon = app.icon
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
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
            let plateRect = bounds.insetBy(dx: HUDMetrics.highlightInset, dy: HUDMetrics.highlightInset)
            let radius = HUDMetrics.iconCornerRadius(plateRect.width)
            let plate = NSBezierPath(roundedRect: plateRect, xRadius: radius, yRadius: radius)
            plate.flatness = 0.1
            NSColor.black.withAlphaComponent(
                NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.45 : 0.18
            ).setFill()
            plate.fill()
        }

        icon.draw(in: bounds)
    }
}
