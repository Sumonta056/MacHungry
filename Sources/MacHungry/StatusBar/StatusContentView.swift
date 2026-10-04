import AppKit
import QuartzCore

@MainActor
final class StatusContentView: NSView {
    private let tintLayer = CALayer()
    private let maskLayer = CALayer()
    private let frameLayer = CALayer()
    private let statsLayer = CALayer()
    private var frameCache: [ObjectIdentifier: CGImage] = [:]
    private var frameSize = NSSize.zero
    private var frameLeftInset: CGFloat = 0
    private var statsSize = NSSize.zero
    private var animationX: CGFloat?

    var contentSize: NSSize {
        let frameHeight = animationX == nil ? 0 : frameSize.height
        return NSSize(width: statsSize.width, height: max(frameHeight, statsSize.height))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for sublayer in [frameLayer, statsLayer] {
            sublayer.contentsGravity = .resize
            maskLayer.addSublayer(sublayer)
        }
        tintLayer.mask = maskLayer
        layer?.addSublayer(tintLayer)
        updateTint()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTint()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? StatusLayout.fallbackBackingScale
        frameLayer.contentsScale = scale
        statsLayer.contentsScale = scale
    }

    func showFrame(_ image: NSImage?) {
        withoutAnimation {
            frameLayer.contents = image.flatMap(cachedCGImage)
        }
    }

    func showStats(_ composition: StatusComposition) {
        withoutAnimation {
            statsLayer.contents = composition.image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        guard composition.image.size != statsSize || composition.animationX != animationX else { return }
        statsSize = composition.image.size
        animationX = composition.animationX
        layoutContent()
    }

    func setAnimationFrame(size: NSSize, leftInset: CGFloat) {
        frameCache.removeAll()
        guard size != frameSize || leftInset != frameLeftInset else { return }
        frameSize = size
        frameLeftInset = leftInset
        layoutContent()
    }

    private func cachedCGImage(for image: NSImage) -> CGImage? {
        let key = ObjectIdentifier(image)
        if let cached = frameCache[key] { return cached }
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        frameCache[key] = cgImage
        return cgImage
    }

    private func layoutContent() {
        let size = contentSize
        withoutAnimation {
            tintLayer.frame = NSRect(origin: .zero, size: size)
            maskLayer.frame = tintLayer.bounds
            frameLayer.isHidden = animationX == nil
            frameLayer.frame = NSRect(x: (animationX ?? 0) - frameLeftInset, y: (size.height - frameSize.height) / 2, width: frameSize.width, height: frameSize.height)
            statsLayer.frame = NSRect(x: 0, y: (size.height - statsSize.height) / 2, width: statsSize.width, height: statsSize.height)
        }
    }

    private func updateTint() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        tintLayer.backgroundColor = isDark ? CGColor(gray: 1, alpha: 1) : CGColor(gray: 0, alpha: 1)
    }

    private func withoutAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }
}
