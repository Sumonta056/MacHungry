import AppKit
import HungryCore

enum StatusImageComposer {
    private enum Part {
        case animationSlot(width: CGFloat)
        case text(NSAttributedString, width: CGFloat, icon: NSImage?)

        var width: CGFloat {
            switch self {
            case .animationSlot(let width): width
            case .text(_, let width, let icon): width + (icon.map { $0.size.width + StatusLayout.iconGap } ?? 0)
            }
        }

        var isAnimation: Bool {
            if case .animationSlot = self { return true }
            return false
        }
    }

    static func compose(segments: [StatusSegment], values: StatusValues, animationWidth: CGFloat) -> StatusComposition {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: StatusLayout.fontSize, weight: StatusLayout.fontWeight),
            .foregroundColor: StatusLayout.textColor,
        ]
        let parts = segments.compactMap { part(for: $0, values: values, animationWidth: animationWidth, attributes: attributes) }
        var origins: [CGFloat] = []
        var x: CGFloat = 0
        for (index, part) in parts.enumerated() {
            if index > 0 {
                x += StatusLayout.segmentGap
            }
            origins.append(x)
            x += part.width
        }
        let height = StatusLayout.height
        let animationX = zip(parts, origins).first { $0.0.isAnimation }?.1
        let image = TemplateImageRenderer.render(size: NSSize(width: x, height: height)) {
            for (part, origin) in zip(parts, origins) {
                guard case .text(let text, _, let icon) = part else { continue }
                var textX = origin
                if let icon {
                    icon.draw(in: NSRect(x: origin, y: (height - icon.size.height) / 2, width: icon.size.width, height: icon.size.height))
                    textX += icon.size.width + StatusLayout.iconGap
                }
                let textSize = text.size()
                text.draw(at: NSPoint(x: textX, y: (height - textSize.height) / 2))
            }
        }
        return StatusComposition(image: image, animationX: animationX)
    }

    private static func part(for segment: StatusSegment, values: StatusValues, animationWidth: CGFloat, attributes: [NSAttributedString.Key: Any]) -> Part? {
        if segment == .animation {
            return animationWidth > 0 ? .animationSlot(width: animationWidth) : nil
        }
        guard let text = StatusLabels.text(for: segment, value: values.value(for: segment)),
              let sample = StatusLabels.text(for: segment, value: StatusLayout.trailingBearingSampleValue) else { return nil }
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let width = ceil(attributed.size().width - trailingBearing(of: NSAttributedString(string: sample, attributes: attributes)))
        return .text(attributed, width: width, icon: icon(for: segment))
    }

    private static func trailingBearing(of text: NSAttributedString) -> CGFloat {
        let ink = text.boundingRect(with: .zero, options: [.usesLineFragmentOrigin, .usesDeviceMetrics])
        return max(0, text.size().width - ink.maxX)
    }

    private static func icon(for segment: StatusSegment) -> NSImage? {
        guard segment == .temperature else { return nil }
        let configuration = NSImage.SymbolConfiguration(pointSize: StatusLayout.fontSize, weight: StatusLayout.fontWeight)
        return NSImage(systemSymbolName: StatusLayout.temperatureSymbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }
}
