import AppKit
import HungryCore
import UniformTypeIdentifiers

@MainActor
final class IconCache {
    static let iconSize = NSSize(width: PopoverLayout.rowIconSize, height: PopoverLayout.rowIconSize)

    private var icons: [String: NSImage] = [:]
    private lazy var genericIcon: NSImage = {
        let icon = NSWorkspace.shared.icon(for: .unixExecutable)
        icon.size = Self.iconSize
        return icon
    }()

    func icon(for app: AppUsage) -> NSImage {
        guard let path = app.identity.bundlePath else { return genericIcon }
        if let cached = icons[path] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = Self.iconSize
        icons[path] = icon
        return icon
    }

    func removeAll() {
        icons.removeAll()
    }
}
