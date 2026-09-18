import AppKit

enum HUDMetrics {
    static let iconSize: CGFloat = 84
    static let minIconSize: CGFloat = 48
    static let iconSpacing: CGFloat = 10
    static let highlightPad: CGFloat = 0
    static let padH: CGFloat = 14
    static let padTop: CGFloat = 15
    static let padBottom: CGFloat = 8
    static let nameHeight: CGFloat = 13
    static let nameGap: CGFloat = 0
    static let nameLift: CGFloat = 2
    static let highlightInset: CGFloat = 2
    static let iconCornerRatio: CGFloat = 0.22
    static let barRadius: CGFloat = 26
    static let maxWidthFraction: CGFloat = 0.72
    static let nameFont = NSFont.systemFont(ofSize: 12, weight: .bold)

    static func iconCornerRadius(_ size: CGFloat) -> CGFloat {
        size * iconCornerRatio
    }

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
