import AppKit
import HungryCore

enum FrameLoader {
    static func frames(for theme: any AnimationTheme, bundle: Bundle = .main) -> [NSImage] {
        guard let directory = bundle.resourceURL?.appendingPathComponent("Themes/\(theme.id)", isDirectory: true) else { return [] }
        let images = theme.frameNames.compactMap { loadFrame(named: $0, in: directory) }
        return images.count == theme.frameCount ? images : []
    }

    static func transparentInsets(of frames: [NSImage]) -> NSEdgeInsets {
        let insets = frames.compactMap(transparentInsets(of:))
        guard let first = insets.first else { return NSEdgeInsetsZero }
        return insets.dropFirst().reduce(first) { result, next in
            NSEdgeInsets(top: 0, left: min(result.left, next.left), bottom: 0, right: min(result.right, next.right))
        }
    }

    private static func transparentInsets(of image: NSImage) -> NSEdgeInsets? {
        guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).max(by: { $0.pixelsWide < $1.pixelsWide }),
              rep.size.width > 0 else { return nil }
        let opaqueColumns = (0..<rep.pixelsWide).filter { x in
            (0..<rep.pixelsHigh).contains { y in (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > opaqueAlphaThreshold }
        }
        guard let firstColumn = opaqueColumns.first, let lastColumn = opaqueColumns.last else { return nil }
        let pointsPerPixel = rep.size.width / CGFloat(rep.pixelsWide)
        let left = (CGFloat(firstColumn) * pointsPerPixel).rounded(.down)
        let right = (CGFloat(rep.pixelsWide - 1 - lastColumn) * pointsPerPixel).rounded(.down)
        return NSEdgeInsets(top: 0, left: left, bottom: 0, right: right)
    }

    private static let opaqueAlphaThreshold: CGFloat = 0.05

    private static func loadFrame(named name: String, in directory: URL) -> NSImage? {
        guard let base = NSImageRep(contentsOf: directory.appendingPathComponent("\(name).png")) else { return nil }
        let size = NSSize(width: base.pixelsWide, height: base.pixelsHigh)
        base.size = size
        let image = NSImage(size: size)
        image.addRepresentation(base)
        if let retina = NSImageRep(contentsOf: directory.appendingPathComponent("\(name)@2x.png")) {
            retina.size = size
            image.addRepresentation(retina)
        }
        image.isTemplate = true
        return image
    }
}
