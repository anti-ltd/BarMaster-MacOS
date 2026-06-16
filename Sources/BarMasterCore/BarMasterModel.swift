import AppKit
import SwiftUI

@MainActor
@Observable
public final class BarMasterModel {

    public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }

    public var hiddenBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenBundleIDs), forKey: "hiddenBundleIDs")
        }
    }

    /// Live menu bar items discovered by the last scan.
    public var discoveredItems: [MenuBarItem] = []
    public var isScanning = false

    // Accessory apps that were terminated to hide their status item.
    // Kept so we can relaunch them and so they stay visible in the list.
    private var terminatedForHiding: [String: TerminatedAppInfo] = [:]

    public init() {
        isEnabled = UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true
        let stored = UserDefaults.standard.array(forKey: "hiddenBundleIDs") as? [String] ?? []
        hiddenBundleIDs = Set(stored)
    }

    public var isMuted: Bool { !isEnabled }

    public var spacerHideSupported: Bool { MenuBarCapabilities.spacerHideSupported }

    public var osLimitationMessage: String? { MenuBarCapabilities.limitationMessage }

    public func start() {
        scanItems()
    }

    public func scanItems() {
        isScanning = true
        var items = MenuBarScanner.scan()

        // Re-inject apps that were terminated for hiding so they stay in the list.
        for (bid, info) in terminatedForHiding
            where !items.contains(where: { $0.bundleID == bid }) {
            items.append(MenuBarItem(
                id: Int(info.pid), pid: info.pid,
                bundleID: bid, appName: info.name,
                icon: info.icon, frame: .zero
            ))
        }

        discoveredItems = items
        isScanning = false
    }

    public func hide(bundleID: String) {
        hiddenBundleIDs.insert(bundleID)
        if let item = discoveredItems.first(where: { $0.bundleID == bundleID }) {
            applyHide(item)
        }
    }

    public func show(bundleID: String) {
        hiddenBundleIDs.remove(bundleID)
        if let item = discoveredItems.first(where: { $0.bundleID == bundleID }) {
            applyShow(item)
        }
    }

    public func isHidden(_ item: MenuBarItem) -> Bool {
        guard let bid = item.bundleID else { return false }
        return hiddenBundleIDs.contains(bid)
    }

    public func toggle(_ item: MenuBarItem) {
        guard let bid = item.bundleID else { return }
        if hiddenBundleIDs.contains(bid) {
            hiddenBundleIDs.remove(bid)
            applyShow(item)
        } else {
            hiddenBundleIDs.insert(bid)
            applyHide(item)
        }
    }

    /// Bring the app to the front, or launch it if it isn't running.
    ///
    /// This is BarMaster's primary action on macOS 27: the OS no longer lets a
    /// third-party app hide or trigger another app's status item (Control Centre
    /// hosts them and exposes no Accessibility children), so the most we can
    /// offer is one-click access to the owning app.
    public func activate(_ item: MenuBarItem) {
        let apps = NSWorkspace.shared.runningApplications

        if let app = apps.first(where: { $0.processIdentifier == item.pid })
            ?? apps.first(where: { $0.bundleIdentifier == item.bundleID }) {
            app.activate()
            return
        }

        // Not running — relaunch from the resolved bundle URL.
        if let bid = item.bundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init()) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    Task { @MainActor in self?.scanItems() }
                }
            }
        }
    }

    // MARK: - Private hiding logic

    private func applyHide(_ item: MenuBarItem) {
        guard let bid = item.bundleID else { return }
        let allApps = NSWorkspace.shared.runningApplications

        // Pure accessory app (menu-bar only): terminate it so the icon disappears.
        // Store enough info to relaunch and keep it in the list.
        if let app = allApps.first(where: { $0.bundleIdentifier == bid }),
           app.activationPolicy == .accessory,
           let url = app.bundleURL {
            terminatedForHiding[bid] = TerminatedAppInfo(
                pid: app.processIdentifier,
                name: app.localizedName ?? bid,
                icon: app.icon,
                url: url
            )
            app.terminate()
            return
        }

        // Regular app with an accessory helper (e.g. Claude + Claude Helper):
        // terminate the helper process — that removes the status item while the
        // main app keeps running. The main app typically relaunches the helper
        // on its own, so we just let that happen when the user un-hides.
        for suffix in [".helper", ".Helper"] {
            if let helper = allApps.first(where: { $0.bundleIdentifier == bid + suffix }) {
                helper.terminate()
                return
            }
        }
    }

    private func applyShow(_ item: MenuBarItem) {
        guard let bid = item.bundleID else { return }

        // If we terminated this app, relaunch it from its stored bundle URL.
        if let info = terminatedForHiding[bid] {
            NSWorkspace.shared.open(info.url)
            terminatedForHiding.removeValue(forKey: bid)
            // Refresh after a short delay so the relaunched item appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.scanItems()
            }
            return
        }

        // Helper-based app: the main app should relaunch the helper automatically.
        // If not, try launching the main app bundle as a fallback.
        let allApps = NSWorkspace.shared.runningApplications
        if let app = allApps.first(where: { $0.bundleIdentifier == bid }),
           let url = app.bundleURL {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct TerminatedAppInfo {
    let pid: pid_t
    let name: String
    let icon: NSImage?
    let url: URL
}
