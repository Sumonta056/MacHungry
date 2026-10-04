import AppKit

enum StatusLayout {
    static let segmentGap: CGFloat = 6
    static let iconGap: CGFloat = 1
    static let temperatureSymbol = "thermometer.medium"
    static let horizontalPadding: CGFloat = 0
    static let fontWeight: NSFont.Weight = .semibold
    static let textColor = NSColor.black
    static let trailingBearingSampleValue = 88.0
    static let fallbackBackingScale: CGFloat = 2

    static var height: CGFloat { NSStatusBar.system.thickness }
    static var fontSize: CGFloat { NSFont.menuBarFont(ofSize: 0).pointSize }
}
