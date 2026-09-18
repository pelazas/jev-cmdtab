import AppKit

enum HUDMetrics {
    static let iconSize: CGFloat = 84
    static let minIconSize: CGFloat = 48
    static let iconSpacing: CGFloat = 18
    static let highlightPad: CGFloat = 4
    static let padH: CGFloat = 22
    static let padTop: CGFloat = 14
    static let padBottom: CGFloat = 12
    static let nameHeight: CGFloat = 15
    static let nameGap: CGFloat = 1
    static let highlightRadius: CGFloat = 16
    static let iconCrop: CGFloat = 0.18
    static let maxWidthFraction: CGFloat = 0.72
    static let nameFont = NSFont.systemFont(ofSize: 13, weight: .regular)

    static func iconSize(count: Int, screenWidth: CGFloat) -> CGFloat {
        guard count > 0 else { return iconSize }
        let maxW = screenWidth * maxWidthFraction
        let available = maxW - padH * 2
        let per = available / CGFloat(count) - iconSpacing
        return min(iconSize, max(minIconSize, per))
    }

    static func panelSize(count: Int, icon: CGFloat) -> NSSize {
        let cell = icon + highlightPad * 2
        let width = padH * 2 + CGFloat(count) * cell + CGFloat(max(0, count - 1)) * iconSpacing
        let height = padTop + cell + nameGap + nameHeight + padBottom
        return NSSize(width: width, height: height)
    }
}
