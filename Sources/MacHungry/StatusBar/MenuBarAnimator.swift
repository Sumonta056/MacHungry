import AppKit
import HungryCore

@MainActor
final class MenuBarAnimator {
    private(set) var theme: any AnimationTheme
    private var frames: [NSImage] = []
    private(set) var frameInsets = NSEdgeInsetsZero
    private var frameIndex = 0
    private var smoothedCPU = 0.0
    private var timer: Timer?
    private var currentInterval: TimeInterval = 0
    private var isRunning = false

    var onFrame: ((NSImage?) -> Void)?
    var onThemeApplied: (() -> Void)?

    var currentFrame: NSImage? {
        frames.isEmpty ? nil : frames[frameIndex]
    }

    var frameSize: NSSize {
        frames.first?.size ?? .zero
    }

    var visibleFrameWidth: CGFloat {
        max(0, frameSize.width - frameInsets.left - frameInsets.right)
    }

    init(theme: any AnimationTheme) {
        self.theme = theme
        apply(theme)
    }

    func setTheme(_ newTheme: any AnimationTheme) {
        apply(newTheme)
        onThemeApplied?()
        restartTimer(force: true)
        onFrame?(currentFrame)
    }

    func update(cpu: Double) {
        smoothedCPU = SpeedCurve.smooth(previous: smoothedCPU, new: cpu)
        restartTimer(force: false)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        restartTimer(force: true)
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    private func apply(_ candidate: any AnimationTheme) {
        var loaded = FrameLoader.frames(for: candidate)
        var chosen = candidate
        if loaded.isEmpty, candidate.id != ThemeRegistry.fallback.id {
            chosen = ThemeRegistry.fallback
            loaded = FrameLoader.frames(for: chosen)
        }
        theme = chosen
        frames = loaded
        frameInsets = FrameLoader.transparentInsets(of: loaded)
        frameIndex = 0
    }

    private func restartTimer(force: Bool) {
        guard isRunning else { return }
        let interval = theme.frameInterval(forCPU: smoothedCPU)
        guard force || timer == nil || SpeedCurve.shouldReplaceTimer(current: currentInterval, new: interval) else { return }
        timer?.invalidate()
        currentInterval = interval
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
        newTimer.tolerance = interval * 0.1
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func advance() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        onFrame?(frames[frameIndex])
    }
}
