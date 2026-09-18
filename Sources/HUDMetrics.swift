import AppKit

enum HUDMetrics {
    static let iconSize: CGFloat = 72
    static let minIconSize: CGFloat = 40
    static let iconSpacing: CGFloat = 10
    static let highlightPad: CGFloat = 6
    static let padH: CGFloat = 22
    static let padTop: CGFloat = 18
    static let padBottom: CGFloat = 14
    static let nameHeight: CGFloat = 22
    static let nameGap: CGFloat = 6
    static let cornerRadius: CGFloat = 28
    static let highlightRadius: CGFloat = 14
    static let maxWidthFraction: CGFloat = 0.72

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
