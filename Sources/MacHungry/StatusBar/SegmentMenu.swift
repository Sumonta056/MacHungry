import AppKit
import HungryCore

@MainActor
final class SegmentMenu: NSObject, NSMenuDelegate {
    enum Title {
        static let show = "Show"
        static let moveLeft = "Move Left"
        static let moveRight = "Move Right"
        static let reset = "Reset Layout"
    }

    let menu = NSMenu()
    private let currentSettings: () -> StatusLayoutSettings
    private let onChange: (StatusLayoutSettings) -> Void

    init(currentSettings: @escaping () -> StatusLayoutSettings, onChange: @escaping (StatusLayoutSettings) -> Void) {
        self.currentSettings = currentSettings
        self.onChange = onChange
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let settings = currentSettings()
        menu.removeAllItems()
        for segment in settings.availableOrder {
            let item = NSMenuItem(title: segment.title, action: nil, keyEquivalent: "")
            item.state = settings.isVisible(segment) ? .on : .off
            item.submenu = submenu(for: segment, settings: settings)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let reset = actionItem(Title.reset, action: #selector(resetLayout(_:)), segment: nil)
        reset.isEnabled = !settings.isDefaultLayout
        menu.addItem(reset)
    }

    private func submenu(for segment: StatusSegment, settings: StatusLayoutSettings) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let show = actionItem(Title.show, action: #selector(toggleVisibility(_:)), segment: segment)
        show.state = settings.isVisible(segment) ? .on : .off
        show.isEnabled = !settings.isVisible(segment) || settings.canHide(segment)
        let left = actionItem(Title.moveLeft, action: #selector(moveLeft(_:)), segment: segment)
        left.isEnabled = settings.canMoveLeft(segment)
        let right = actionItem(Title.moveRight, action: #selector(moveRight(_:)), segment: segment)
        right.isEnabled = settings.canMoveRight(segment)
        submenu.items = [show, left, right]
        return submenu
    }

    private func actionItem(_ title: String, action: Selector, segment: StatusSegment?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = segment?.rawValue
        return item
    }

    private func segment(of item: NSMenuItem) -> StatusSegment? {
        (item.representedObject as? String).flatMap(StatusSegment.init(rawValue:))
    }

    @objc private func toggleVisibility(_ sender: NSMenuItem) {
        guard let segment = segment(of: sender) else { return }
        onChange(currentSettings().togglingVisibility(of: segment))
    }

    @objc private func moveLeft(_ sender: NSMenuItem) {
        guard let segment = segment(of: sender) else { return }
        onChange(currentSettings().movingLeft(segment))
    }

    @objc private func moveRight(_ sender: NSMenuItem) {
        guard let segment = segment(of: sender) else { return }
        onChange(currentSettings().movingRight(segment))
    }

    @objc private func resetLayout(_ sender: NSMenuItem) {
        onChange(.default)
    }
}
