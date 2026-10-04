import AppKit
import SwiftUI
import HungryCore
import HungrySystem

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store: StatsStore
    private let monitor: StatsMonitor
    private let animator: MenuBarAnimator
    private let iconCache: IconCache
    private let contentView = StatusContentView(frame: .zero)
    private var placeholderSize = NSSize.zero
    private var layout: StatusLayoutSettings
    private var values = StatusValues()
    private var outsideClickMonitor: Any?
    private lazy var segmentMenu = SegmentMenu(
        currentSettings: { [unowned self] in layout },
        onChange: { [unowned self] newLayout in applyLayout(newLayout) }
    )

    init(store: StatsStore, monitor: StatsMonitor, animator: MenuBarAnimator, iconCache: IconCache, layout: StatusLayoutSettings) {
        self.store = store
        self.monitor = monitor
        self.animator = animator
        self.iconCache = iconCache
        self.layout = layout.withUnavailable(monitor.isTemperatureAvailable ? [] : [.temperature])
        super.init()
        popover.behavior = .transient
        popover.delegate = self
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.toolTip = UsageFormatter.tooltip(cpu: nil, memory: nil)
            button.addSubview(contentView)
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        animator.onFrame = { [weak self] frame in self?.contentView.showFrame(frame) }
        animator.onThemeApplied = { [weak self] in self?.applyThemeSize() }
        monitor.onSystemSample = { [weak self] snapshot in self?.apply(snapshot) }
        applyThemeSize()
        contentView.showFrame(animator.currentFrame)
        redrawStats()
        applyLayoutToServices()
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, isMenuClick(event) {
            showLayoutMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    private func showLayoutMenu(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(button)
        }
        statusItem.menu = segmentMenu.menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(button)
            return
        }
        let model = PopoverModel(
            topAppsLimit: monitor.topLimit,
            onThemeChange: { [weak self] theme in self?.animator.setTheme(theme) },
            onTopAppsLimitChange: { [weak self] limit in self?.monitor.topLimit = limit }
        )
        let hosting = NSHostingController(rootView: PopoverView(store: store, iconCache: iconCache, quitCache: QuitCache(), model: model))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        monitor.startProcessSampling()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startOutsideClickMonitor()
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.popover.performClose(nil)
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    func popoverDidClose(_ notification: Notification) {
        stopOutsideClickMonitor()
        monitor.stopProcessSampling()
        iconCache.removeAll()
        popover.contentViewController = nil
    }

    private func isMenuClick(_ event: NSEvent) -> Bool {
        event.type == .rightMouseUp || event.modifierFlags.contains(.control)
    }

    private func applyLayout(_ requested: StatusLayoutSettings) {
        let newLayout = requested.withUnavailable(layout.unavailable)
        guard newLayout != layout else { return }
        layout = newLayout
        LayoutPreference.save(newLayout)
        applyLayoutToServices()
        redrawStats()
    }

    private func applyLayoutToServices() {
        monitor.includesTemperature = layout.isVisible(.temperature)
        if layout.isVisible(.animation) {
            animator.start()
        } else {
            animator.stop()
        }
    }

    private func apply(_ snapshot: SystemSnapshot) {
        let cpuTemperature = snapshot.temperature?.cpu
        values = StatusValues(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, temperature: cpuTemperature)
        redrawStats()
        statusItem.button?.toolTip = UsageFormatter.tooltip(cpu: snapshot.cpuPercent, memory: snapshot.memory?.percent, temperature: cpuTemperature)
        if let cpu = snapshot.cpuPercent {
            animator.update(cpu: cpu)
        }
    }

    private func applyThemeSize() {
        contentView.setAnimationFrame(size: animator.frameSize, leftInset: animator.frameInsets.left)
        redrawStats()
    }

    private func redrawStats() {
        let composition = StatusImageComposer.compose(segments: layout.visibleSegments, values: values, animationWidth: animator.visibleFrameWidth)
        contentView.showStats(composition)
        updatePlaceholder()
    }

    private func updatePlaceholder() {
        guard let button = statusItem.button else { return }
        let size = contentView.contentSize
        guard size != placeholderSize else { return }
        placeholderSize = size
        let placeholder = NSImage(size: size)
        placeholder.isTemplate = true
        button.image = placeholder
        statusItem.length = size.width + StatusLayout.horizontalPadding * 2
        button.layoutSubtreeIfNeeded()
        contentView.frame = NSRect(
            x: StatusLayout.horizontalPadding,
            y: ((button.bounds.height - size.height) / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }
}
