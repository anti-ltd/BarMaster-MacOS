import AppKit
import CoreGraphics

// Enumerates visible windows that sit in the menu bar strip.
// Uses CGWindowListCopyWindowInfo — window metadata (bounds, owner PID) is
// available without Screen Recording permission. Window contents/screenshots
// are not requested here.
@MainActor
public enum MenuBarScanner {

    public static func scan() -> [MenuBarItem] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        // Menu bar occupies y == 0 (CG screen coords, top-left origin).
        // Allow a small fudge: some items render 1-2pt above 0 on HiDPI.
        let barMaxY: CGFloat = 4
        // Each app with a status item may have multiple small windows in the
        // bar (item window + button layer). De-duplicate by pid: one entry per
        // app, using the leftmost window as the representative frame.
        var byPID: [pid_t: MenuBarItem] = [:]

        for info in list {
            guard
                let wid    = info[kCGWindowNumber as String]       as? Int,
                let bounds = info[kCGWindowBounds as String]       as? [String: CGFloat],
                let y      = bounds["Y"],
                let h      = bounds["Height"],
                let w      = bounds["Width"],
                let pid    = info[kCGWindowOwnerPID as String]     as? pid_t,
                y <= barMaxY,
                h <= NSStatusBar.system.thickness + 8,
                w > 0
            else { continue }

            let frame = CGRect(x: bounds["X"] ?? 0, y: y, width: w, height: h)

            if let existing = byPID[pid] {
                // Keep the leftmost window as the representative frame.
                if frame.minX < existing.frame.minX {
                    byPID[pid] = MenuBarItem(
                        id: wid, pid: pid,
                        bundleID: existing.bundleID,
                        appName: existing.appName,
                        icon: existing.icon,
                        frame: frame
                    )
                }
                continue
            }

            let app = NSRunningApplication(processIdentifier: pid)
            byPID[pid] = MenuBarItem(
                id: wid,
                pid: pid,
                bundleID: app?.bundleIdentifier,
                appName: app?.localizedName
                    ?? info[kCGWindowOwnerName as String] as? String
                    ?? "PID \(pid)",
                icon: app?.icon,
                frame: frame
            )
        }

        // Sort left → right so the list matches visual order in the menu bar.
        return byPID.values.sorted { $0.frame.minX < $1.frame.minX }
    }
}
