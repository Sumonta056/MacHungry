import AppKit

enum TemplateImageRenderer {
    static let scale: CGFloat = 2

    static func render(size: NSSize, draw: () -> Void) -> NSImage {
        let image = NSImage(size: size)
        guard size.width > 0, size.height > 0,
              let rep = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: Int((size.width * scale).rounded(.up)),
                  pixelsHigh: Int((size.height * scale).rounded(.up)),
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              ) else { return image }
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return image }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        draw()
        NSGraphicsContext.restoreGraphicsState()
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }
}
