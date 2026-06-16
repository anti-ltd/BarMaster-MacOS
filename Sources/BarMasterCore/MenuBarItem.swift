import AppKit

public struct MenuBarItem: Identifiable {
    public let id: Int  // CGWindowID / windowNumber
    public let pid: pid_t
    public let bundleID: String?
    public let appName: String
    public let icon: NSImage?
    public let frame: CGRect

    // System processes that own the clock, Spotlight, Control Center, etc.
    // These can't be hidden safely — exclude them from user-facing controls.
    private static let systemBundleIDs: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.systemuiserver",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
        "com.apple.WindowManager",
    ]

    public var isHideable: Bool {
        guard let bid = bundleID else { return false }
        return !Self.systemBundleIDs.contains(bid)
    }

    /// A real third-party app the user can launch / bring to the front.
    /// macOS 27 removed every way to hide another app's status item, so the
    /// product surface is "jump to the app", not "hide its icon".
    public var isLaunchable: Bool { isHideable }
}
