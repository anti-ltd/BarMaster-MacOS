import AppKit
import CoreGraphics

// Enumerates visible windows that sit in the menu bar strip.
// Uses CGWindowListCopyWindowInfo — window metadata (bounds, owner PID) is
// available without Screen Recording permission. Window contents/screenshots
// are not requested here.
//
// macOS 26+: third-party status items are hosted by Control Centre rather than
// their originating process. A supplemental running-apps pass recovers those apps.
@MainActor
public enum MenuBarScanner {

    public static func scan() -> [MenuBarItem] {
        // NSStatusBar.system.thickness is unreliable on macOS 26+ (returns legacy
        // value while actual windows are taller). Derive the true height from
        // screen geometry: the gap between the full frame and the visible frame.
        let menuBarHeight: CGFloat = {
            guard let screen = NSScreen.main else { return NSStatusBar.system.thickness }
            let h = screen.frame.maxY - screen.visibleFrame.maxY
            return h > 0 ? h : NSStatusBar.system.thickness
        }()
        // Exclude full-width overlay windows (e.g. Window Server background bar).
        let screenWidth = NSScreen.main?.frame.width ?? CGFloat.greatestFiniteMagnitude

        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return inferFromRunningApps()
        }

        // Menu bar occupies y == 0 (CG screen coords, top-left origin).
        // Allow a small fudge: some items render 1-2pt above 0 on HiDPI.
        let barMaxY: CGFloat = 4

        // Each app with a status item may have multiple small windows in the
        // bar (item window + button layer). De-duplicate by pid: one entry per
        // app, using the leftmost window as the representative frame.
        var byPID: [pid_t: MenuBarItem] = [:]

        for info in list {
            guard
                let wid    = info[kCGWindowNumber as String]   as? Int,
                let bounds = info[kCGWindowBounds as String]   as? [String: CGFloat],
                let y      = bounds["Y"],
                let h      = bounds["Height"],
                let w      = bounds["Width"],
                let pid    = info[kCGWindowOwnerPID as String] as? pid_t,
                y <= barMaxY,
                h <= menuBarHeight + 8,
                w > 0,
                w < screenWidth
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
        var items = byPID.values.sorted { $0.frame.minX < $1.frame.minX }

        // macOS 26+: status items are hosted by Control Centre, so the window
        // scan only finds system processes. When no third-party items appear,
        // supplement with running apps that are likely to own status items.
        let hasThirdParty = items.contains { item in
            guard let bid = item.bundleID else { return false }
            return !bid.hasPrefix("com.apple.")
        }
        if !hasThirdParty {
            let existingBIDs = Set(items.compactMap { $0.bundleID })
            for inferred in inferFromRunningApps()
                where !existingBIDs.contains(inferred.bundleID ?? "") {
                items.append(inferred)
            }
        }

        return items
    }

    // Infer status-item-bearing apps from the running process list.
    // Used on macOS 26+ where CGWindowListCopyWindowInfo attributes all status
    // item windows to Control Centre rather than the originating app.
    private static func inferFromRunningApps() -> [MenuBarItem] {
        let ownBID = Bundle.main.bundleIdentifier
        let allApps = NSWorkspace.shared.runningApplications
        var result: [String: MenuBarItem] = [:]

        // Pass 1: accessory-policy apps that are not Apple system processes
        // or obvious helper/renderer sub-processes.
        for app in allApps {
            guard app.activationPolicy == .accessory else { continue }
            guard let bid = app.bundleIdentifier else { continue }
            guard bid != ownBID else { continue }
            guard !bid.hasPrefix("com.apple.") else { continue }
            guard !looksLikeHelperBundle(bid) else { continue }
            guard result[bid] == nil else { continue }

            result[bid] = MenuBarItem(
                id: Int(app.processIdentifier),
                pid: app.processIdentifier,
                bundleID: bid,
                appName: app.localizedName ?? bid,
                icon: app.icon,
                frame: .zero
            )
        }

        // Pass 2: regular-policy apps that have an accessory ".helper" / ".Helper"
        // sibling process — a common pattern for apps that add a status item via
        // a dedicated helper (e.g. Claude → Claude Helper).
        for app in allApps where app.activationPolicy == .regular {
            guard let bid = app.bundleIdentifier else { continue }
            guard bid != ownBID else { continue }
            guard !bid.hasPrefix("com.apple.") else { continue }
            guard result[bid] == nil else { continue }

            let hasAccessoryHelper = allApps.contains {
                $0.activationPolicy == .accessory && (
                    $0.bundleIdentifier == bid + ".helper" ||
                    $0.bundleIdentifier == bid + ".Helper"
                )
            }
            guard hasAccessoryHelper else { continue }

            result[bid] = MenuBarItem(
                id: Int(app.processIdentifier),
                pid: app.processIdentifier,
                bundleID: bid,
                appName: app.localizedName ?? bid,
                icon: app.icon,
                frame: .zero
            )
        }

        return result.values.sorted { $0.appName < $1.appName }
    }

    private static func looksLikeHelperBundle(_ bid: String) -> Bool {
        let helperSuffixes = [
            ".helper", ".Helper", ".Renderer", ".Plugin",
            ".GPU", ".Networking", ".WebContent"
        ]
        return helperSuffixes.contains { bid.hasSuffix($0) }
    }
}
