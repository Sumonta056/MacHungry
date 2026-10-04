import AppKit

struct FrameSpec {
    let theme: String
    let size: NSSize
    let count: Int
    let scale: CGFloat
    let yShift: CGFloat
    let lineBoost: CGFloat
    let draw: (Int, Int) -> Void
}

nonisolated(unsafe) var lineBoost: CGFloat = 1

func stroke(_ points: [CGPoint], width: CGFloat = 1.6) {
    guard let first = points.first else { return }
    let path = NSBezierPath()
    path.move(to: first)
    points.dropFirst().forEach { path.line(to: $0) }
    path.lineWidth = width * lineBoost
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func dot(_ center: CGPoint, radius: CGFloat) {
    NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
}

func leg(from hip: CGPoint, length: CGFloat, degrees: CGFloat) -> CGPoint {
    let radians = degrees * .pi / 180
    return CGPoint(x: hip.x + length * sin(radians), y: hip.y - length * cos(radians))
}

func catFoot(phase: CGFloat, ground: CGFloat) -> CGPoint {
    let stance: CGFloat = 0.6
    let reach: CGFloat = 1.9
    let p = phase - floor(phase)
    if p < stance {
        return CGPoint(x: reach - 2 * reach * p / stance, y: ground)
    }
    let s = (p - stance) / (1 - stance)
    let eased = s * s * (3 - 2 * s)
    return CGPoint(x: -reach + 2 * reach * eased, y: ground + 1.1 * sin(.pi * s))
}

func catLeg(hip: CGPoint, foot: CGPoint, kneeForward: Bool, width: CGFloat) {
    let segment: CGFloat = 2.7
    let dx = foot.x - hip.x
    let dy = foot.y - hip.y
    let distance = min(hypot(dx, dy), segment * 2 - 0.01)
    let bend = sqrt(max(segment * segment - distance * distance / 4, 0))
    let side: CGFloat = kneeForward ? 1 : -1
    let knee = CGPoint(
        x: (hip.x + foot.x) / 2 - side * dy / distance * bend,
        y: (hip.y + foot.y) / 2 + side * dx / distance * bend
    )
    stroke([hip, knee, foot], width: width)
}

func drawCat(frame: Int, count: Int) {
    let t = CGFloat(frame) / CGFloat(count)
    let bob = 0.25 * cos(4 * .pi * t)
    let ground: CGFloat = 2.6
    let hipY = 8.4 + bob
    let legs: [(hipX: CGFloat, offset: CGFloat, front: Bool, width: CGFloat)] = [
        (7.6, 0.5, false, 1.05),
        (13.6, 0.75, true, 1.05),
        (7.0, 0.0, false, 1.3),
        (13.0, 0.25, true, 1.3),
    ]
    for leg in legs {
        let foot = catFoot(phase: t + leg.offset, ground: ground)
        catLeg(hip: CGPoint(x: leg.hipX, y: hipY), foot: CGPoint(x: leg.hipX + foot.x, y: foot.y), kneeForward: leg.front, width: leg.width)
    }
    let body = NSBezierPath()
    body.move(to: CGPoint(x: 5.2, y: 8.6 + bob))
    body.curve(to: CGPoint(x: 10, y: 12.2 + bob), controlPoint1: CGPoint(x: 4.6, y: 11.4 + bob), controlPoint2: CGPoint(x: 7.4, y: 12.3 + bob))
    body.curve(to: CGPoint(x: 16.4, y: 11.6 + bob), controlPoint1: CGPoint(x: 12.8, y: 12.1 + bob), controlPoint2: CGPoint(x: 15, y: 12.4 + bob))
    body.curve(to: CGPoint(x: 14.8, y: 7.6 + bob), controlPoint1: CGPoint(x: 16.8, y: 9.6 + bob), controlPoint2: CGPoint(x: 16.2, y: 7.6 + bob))
    body.curve(to: CGPoint(x: 6.6, y: 7.8 + bob), controlPoint1: CGPoint(x: 12, y: 8.4 + bob), controlPoint2: CGPoint(x: 9, y: 8.4 + bob))
    body.curve(to: CGPoint(x: 5.2, y: 8.6 + bob), controlPoint1: CGPoint(x: 5.8, y: 7.6 + bob), controlPoint2: CGPoint(x: 5.3, y: 8 + bob))
    body.fill()
    let headBob = bob * 0.6
    dot(CGPoint(x: 17.6, y: 12.6 + headBob), radius: 2.4)
    NSBezierPath(ovalIn: CGRect(x: 18.4, y: 10.9 + headBob, width: 2.6, height: 2.1)).fill()
    let ears = NSBezierPath()
    ears.move(to: CGPoint(x: 15.6, y: 13.6 + headBob))
    ears.line(to: CGPoint(x: 16.1, y: 16.6 + headBob))
    ears.line(to: CGPoint(x: 17.7, y: 14.6 + headBob))
    ears.close()
    ears.move(to: CGPoint(x: 17.9, y: 14.7 + headBob))
    ears.line(to: CGPoint(x: 19.3, y: 16.5 + headBob))
    ears.line(to: CGPoint(x: 19.6, y: 13.4 + headBob))
    ears.close()
    ears.fill()
    let sway = sin(2 * .pi * t)
    let tail = NSBezierPath()
    tail.move(to: CGPoint(x: 5.6, y: 10.6 + bob))
    tail.curve(
        to: CGPoint(x: 2.2 + 0.4 * sway, y: 15.2 + 0.5 * sway),
        controlPoint1: CGPoint(x: 3.0, y: 10.4 + bob),
        controlPoint2: CGPoint(x: 1.4 - 0.5 * sway, y: 12.4)
    )
    tail.lineWidth = 1.3 * lineBoost
    tail.lineCapStyle = .round
    tail.stroke()
}

func drawPushUp(frame: Int, count: Int) {
    let phase = CGFloat(frame) / CGFloat(count) * 2 * .pi
    let up = (cos(phase) + 1) / 2
    stroke([CGPoint(x: 1, y: 1), CGPoint(x: 23, y: 1)], width: 1)
    let feet = CGPoint(x: 3, y: 2.5)
    let hand = CGPoint(x: 17, y: 2.5)
    let shoulder = CGPoint(x: 17, y: 4.5 + 6 * up)
    stroke([feet, shoulder], width: 2)
    let elbow = CGPoint(x: 17 - 3 * (1 - up), y: (shoulder.y + hand.y) / 2)
    stroke([shoulder, elbow, hand], width: 1.4)
    dot(CGPoint(x: shoulder.x + 3, y: shoulder.y + 1.2), radius: 2.2)
}

func drawPullUp(frame: Int, count: Int) {
    let phase = CGFloat(frame) / CGFloat(count) * 2 * .pi
    let up = (1 - cos(phase)) / 2
    let barY: CGFloat = 16.5
    stroke([CGPoint(x: 1, y: barY), CGPoint(x: 17, y: barY)], width: 1.5)
    let shoulderY = 9.5 + 4.5 * up
    let bend = 2.5 * up
    let elbowY = (barY + shoulderY) / 2
    stroke([CGPoint(x: 6, y: barY), CGPoint(x: 6 - bend, y: elbowY), CGPoint(x: 7.5, y: shoulderY)], width: 1.3)
    stroke([CGPoint(x: 12, y: barY), CGPoint(x: 12 + bend, y: elbowY), CGPoint(x: 10.5, y: shoulderY)], width: 1.3)
    stroke([CGPoint(x: 7.5, y: shoulderY), CGPoint(x: 10.5, y: shoulderY)], width: 1.6)
    let hip = CGPoint(x: 9, y: shoulderY - 5)
    stroke([CGPoint(x: 9, y: shoulderY), hip], width: 1.8)
    stroke([hip, CGPoint(x: 7.5, y: shoulderY - 9)], width: 1.4)
    stroke([hip, CGPoint(x: 10.5, y: shoulderY - 9)], width: 1.4)
    dot(CGPoint(x: 9, y: shoulderY + 2.3), radius: 2)
}

func writePNG(size: NSSize, scale: CGFloat, contentScale: CGFloat, yShift: CGFloat, to url: URL, draw: () -> Void) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale),
        pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }
    rep.size = size
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.black.setStroke()
    NSColor.black.setFill()
    let transform = NSAffineTransform()
    transform.translateX(by: 0, yBy: yShift)
    transform.scale(by: contentScale)
    transform.concat()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}

let specs = [
    FrameSpec(theme: "cat", size: NSSize(width: 31, height: 20), count: 8, scale: 1.25, yShift: -2.4, lineBoost: 1.1, draw: drawCat),
    FrameSpec(theme: "pushup", size: NSSize(width: 35, height: 20), count: 6, scale: 1.45, yShift: -0.8, lineBoost: 1.05, draw: drawPushUp),
    FrameSpec(theme: "pullup", size: NSSize(width: 20, height: 20), count: 6, scale: 1.1, yShift: 0, lineBoost: 1.0, draw: drawPullUp),
]

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Resources/Themes", isDirectory: true)

for spec in specs {
    let directory = root.appendingPathComponent(spec.theme, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    lineBoost = spec.lineBoost
    for frame in 0..<spec.count {
        for (scale, suffix) in [(CGFloat(1), ""), (CGFloat(2), "@2x")] {
            let url = directory.appendingPathComponent("frame-\(frame + 1)\(suffix).png")
            try writePNG(size: spec.size, scale: scale, contentScale: spec.scale, yShift: spec.yShift, to: url) { spec.draw(frame, spec.count) }
        }
    }
    print("\(spec.theme): \(spec.count) frames")
}
