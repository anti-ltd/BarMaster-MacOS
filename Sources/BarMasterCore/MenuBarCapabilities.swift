import AppKit
import CoreGraphics

/// Runtime facts about the host macOS menu bar. macOS 27 (Golden Gate) moved all
/// status items into a single Window Server surface, which breaks the spacer-width
/// hide/reveal trick BarMaster relied on in Tahoe.
@MainActor
public enum MenuBarCapabilities {

    /// Whether widening an `NSStatusItem` can push left-hand neighbours off-screen.
    public static var spacerHideSupported: Bool {
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            return false
        }
        return !usesUnifiedMenuBarWindow
    }

    /// macOS 27+ exposes one full-width menu bar window instead of per-item windows.
    public static var usesUnifiedMenuBarWindow: Bool {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
        }

        let menuBarHeight = derivedMenuBarHeight()
        let screenWidth = NSScreen.main?.frame.width ?? .greatestFiniteMagnitude
        let barMaxY: CGFloat = 4

        var itemWindows = 0
        for info in list {
            guard
                let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                let y = bounds["Y"],
                let h = bounds["Height"],
                let w = bounds["Width"],
                y <= barMaxY,
                h <= menuBarHeight + 8,
                w > 0,
                w < screenWidth
            else { continue }
            itemWindows += 1
        }
        return itemWindows == 0
    }

    public static var limitationMessage: String? {
        guard !spacerHideSupported else { return nil }
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 {
            return """
            macOS 27 hosts all menu bar icons in a single Control Centre surface, so \
            no third-party app can hide or rearrange another app's icon. BarMaster lists \
            your menu-bar apps in the Apps tab so you can jump to any of them in one click. \
            To remove a supported icon, use System Settings → Control Centre.
            """
        }
        return """
        This macOS version no longer supports BarMaster's divider hide/reveal trick. \
        Use the Apps tab to jump to your menu-bar apps instead.
        """
    }

    public static func derivedMenuBarHeight() -> CGFloat {
        guard let screen = NSScreen.main else { return NSStatusBar.system.thickness }
        let h = screen.frame.maxY - screen.visibleFrame.maxY
        return h > 0 ? h : NSStatusBar.system.thickness
    }
}
