import AppKit

// STAGE 0 FEASIBILITY SPIKE — THROWAWAY. Delete once the spacer trick is proven
// (or disproven) on macOS 26. Run with: BarMaster --spike
//
// Proves on THIS OS:
//  (a) 3 NSStatusItems with autosaveName persist their bar position across relaunch.
//  (b) Widening a spacer item's .length pushes neighboring third-party icons off the
//      LEFT screen edge (hidden); shrinking it reveals them.
//  (c) No Accessibility / Screen Recording permission is needed for (b).
//
// A small floating window drives the spacer width and logs diagnostics.
@MainActor
final class SpikeController: NSObject {

    private var labelItem: NSStatusItem?     // a visible marker icon ("A")
    // Two items. Roles assigned every toggle by physical position: the RIGHTMOST
    // is always the clickable chevron; the leftmost is the visible "|" divider
    // that expands to hide. So the chevron can never end up left of the divider
    // and hide itself, no matter how the user Cmd-drags them.
    private var itemA: NSStatusItem?
    private var itemB: NSStatusItem?
    private let chevron = NSImage(
        systemSymbolName: "chevron.left.chevron.right",
        accessibilityDescription: "BarMaster toggle"
    )

    private var collapsed = false
    private let hiddenLength: CGFloat = 10_000
    private let shownLength: CGFloat = 8

    private var window: NSWindow?
    private var statusLabel: NSTextField?

    func start() {
        installItems()
        installPanel()
        logState(note: "launched")
    }

    // MARK: - Status items

    private func installItems() {
        let bar = NSStatusBar.system

        let label = bar.statusItem(withLength: NSStatusItem.variableLength)
        label.autosaveName = "spike.label"
        label.button?.title = "A"
        labelItem = label

        // Two items, both clickable. Identity (chevron vs "|") is assigned by
        // syncRoles() based on which is rightmost.
        for (name, hold) in [("spike.a", { (i: NSStatusItem) in self.itemA = i }),
                             ("spike.b", { (i: NSStatusItem) in self.itemB = i })] {
            let item = bar.statusItem(withLength: shownLength)
            item.autosaveName = name
            item.button?.target = self
            item.button?.action = #selector(toggle)
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
        spacer.button?.title = "|"                 // visible divider
        spacer.length = collapsed ? hiddenLength : shownLength
    }

    @objc private func toggle() {
        collapsed.toggle()
        syncRoles()   // re-pick rightmost-as-chevron, then size the divider
        logState(note: collapsed ? "collapsed (spacer=10000)" : "expanded (spacer=8)")
    }

    // MARK: - Control panel

    private func installPanel() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 200),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        win.title = "BarMaster Spike"
        win.center()
        win.isReleasedWhenClosed = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let hide = NSButton(title: "Widen spacer (hide left icons)", target: self, action: #selector(doHide))
        let show = NSButton(title: "Shrink spacer (reveal)", target: self, action: #selector(doShow))
        let dump = NSButton(title: "Log autosave positions", target: self, action: #selector(dumpPositions))

        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        statusLabel = label

        for v in [hide, show, dump, label] { stack.addArrangedSubview(v) }

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            label.widthAnchor.constraint(equalToConstant: 428),
        ])
        win.contentView = content
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    @objc private func doHide() { collapsed = false; toggle() }
    @objc private func doShow() { collapsed = true; toggle() }

    @objc private func dumpPositions() { logState(note: "manual dump") }

    // MARK: - Diagnostics

    private func logState(note: String) {
        let trusted = AXIsProcessTrusted()
        // macOS stores status-item positions under this key prefix when autosaveName is set.
        func pos(_ name: String) -> String {
            let key = "NSStatusItem Preferred Position \(name)"
            if let n = UserDefaults.standard.object(forKey: key) as? NSNumber {
                return n.stringValue
            }
            return "—"
        }
        let r = roles()
        let text = """
        [\(note)]
        AXIsProcessTrusted: \(trusted)   (false ⇒ hide/reveal works WITHOUT Accessibility)
        collapsed: \(collapsed)   divider(leftmost).length=\(r?.spacer.length ?? -1)
        autosave positions (persist across relaunch after Cmd-drag):
          A      = \(pos("spike.label"))
          itemA  = \(pos("spike.a"))
          itemB  = \(pos("spike.b"))
        """
        statusLabel?.stringValue = text
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }
}
