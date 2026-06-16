import AppKit

/// Best-effort detection for Tahoe+ menu bar allow-list blocks. Apple does not
/// expose the allow state directly; a status item with a button window that never
/// lands on a screen is the usual signature.
@MainActor
public enum MenuBarAllowListGuidance {

    private static let dismissedKey = "hasShownMenuBarAllowListGuidance"
    private static let dismissedAtKey = "menuBarAllowListGuidanceDismissedAt"
    private static let reshowInterval: TimeInterval = 86_400

    public static func isLikelyBlocked(_ item: NSStatusItem) -> Bool {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else {
            return false
        }
        guard item.isVisible, let button = item.button, button.window != nil else {
            return false
        }
        return button.window?.screen == nil
    }

    public static func shouldPresentGuidance(for item: NSStatusItem) -> Bool {
        guard isLikelyBlocked(item) else { return false }
        if !UserDefaults.standard.bool(forKey: dismissedKey) { return true }
        let dismissedAt = UserDefaults.standard.double(forKey: dismissedAtKey)
        guard dismissedAt > 0 else { return true }
        return Date().timeIntervalSince1970 - dismissedAt >= reshowInterval
    }

    public static func presentIfNeeded(for item: NSStatusItem, appName: String) {
        guard shouldPresentGuidance(for: item) else { return }

        let alert = NSAlert()
        alert.messageText = "\(appName) can't show its menu bar icon"
        alert.informativeText = """
        macOS may be blocking \(appName) in System Settings → Menu Bar. The app is \
        running, but its icon can stay hidden until you allow it there.
        """
        alert.addButton(withTitle: "Open Menu Bar Settings")
        alert.addButton(withTitle: "Dismiss")

        let response = alert.runModal()
        UserDefaults.standard.set(true, forKey: dismissedKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: dismissedAtKey)

        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.MenuBarSettings") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
