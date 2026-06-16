import AppKit

// Owns BarMaster's control status items and the hide/reveal mechanic.
//
// Mechanic (macOS 26 and earlier): status items lay out right-to-left, so
// widening an item pushes everything to its LEFT off the screen edge (hidden).
// Shrinking it reveals them. macOS 27's unified menu bar breaks this — see
// `MenuBarCapabilities.spacerHideSupported`.
//
// Two items, roles assigned by physical position every toggle: the RIGHTMOST is
// always the clickable chevron, the leftmost is the visible "|" divider that
// flexes its width. This guarantees the chevron can never end up left of the
// divider and hide itself, no matter how the user Cmd-drags them.
//
// The user Cmd-drags the icons they want hidden to sit LEFT of the divider.
@MainActor
public final class SpacerManager: NSObject {

    public let hideRevealSupported: Bool

    private var itemA: NSStatusItem?
    private var itemB: NSStatusItem?

    private let chevron = NSImage(
        systemSymbolName: "chevron.left.chevron.right",
        accessibilityDescription: "BarMaster — hide/reveal menu bar icons"
    )

    private let hiddenLength: CGFloat = 10_000
    private let shownLength: CGFloat = 8

    /// Whether the hidden section is currently collapsed (icons pushed off-screen).
    public private(set) var collapsed = false

    /// Right-click handler for the chevron (e.g. open settings). Optional.
    private let secondaryAction: (@MainActor () -> Void)?

    public init(secondaryAction: (@MainActor () -> Void)? = nil) {
        self.secondaryAction = secondaryAction
        hideRevealSupported = MenuBarCapabilities.spacerHideSupported
        super.init()
        StatusItemVisibilityCleanup.clearBarMasterOverrides()
        install()
    }

    private func install() {
        let bar = NSStatusBar.system
        guard hideRevealSupported else { return }

        for (name, hold) in [("barmaster.itemA", { (i: NSStatusItem) in self.itemA = i }),
                             ("barmaster.itemB", { (i: NSStatusItem) in self.itemB = i })] {
            let item = bar.statusItem(withLength: shownLength)
            item.autosaveName = name
            item.button?.target = self
            item.button?.action = #selector(handleClick(_:))
            item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
            hold(item)
        }
        syncRoles()
    }

    // (control = rightmost = chevron, spacer = leftmost = "|").
    private func roles() -> (control: NSStatusItem, spacer: NSStatusItem)? {
        guard let a = itemA, let b = itemB,
              let ax = a.button?.window?.frame.origin.x,
              let bx = b.button?.window?.frame.origin.x else { return nil }
        return ax >= bx ? (a, b) : (b, a)
    }

    private func syncRoles() {
        guard let (control, spacer) = roles() else { return }
        control.button?.image = chevron
        control.button?.title = ""
        control.length = NSStatusItem.variableLength
        spacer.button?.image = nil
        spacer.button?.title = "|"
        spacer.length = collapsed ? hiddenLength : shownLength
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp ||
            (event?.modifierFlags.contains(.control) ?? false)
        if isSecondary, let secondaryAction {
            secondaryAction()
        } else if hideRevealSupported {
            toggle()
        } else if let secondaryAction {
            secondaryAction()
        }
    }

    /// Collapse ⇄ reveal the hidden section.
    public func toggle() {
        guard hideRevealSupported else { return }
        collapsed.toggle()
        syncRoles()   // re-pick rightmost-as-chevron, then size the divider
    }
}
