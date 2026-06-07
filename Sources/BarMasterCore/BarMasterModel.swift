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

    public init() {
        isEnabled = UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true
        let stored = UserDefaults.standard.array(forKey: "hiddenBundleIDs") as? [String] ?? []
        hiddenBundleIDs = Set(stored)
    }

    public var isMuted: Bool { !isEnabled }

    public func start() {
        scanItems()
    }

    public func scanItems() {
        isScanning = true
        discoveredItems = MenuBarScanner.scan()
        isScanning = false
    }

    public func hide(bundleID: String) {
        hiddenBundleIDs.insert(bundleID)
    }

    public func show(bundleID: String) {
        hiddenBundleIDs.remove(bundleID)
    }

    public func isHidden(_ item: MenuBarItem) -> Bool {
        guard let bid = item.bundleID else { return false }
        return hiddenBundleIDs.contains(bid)
    }

    public func toggle(_ item: MenuBarItem) {
        guard let bid = item.bundleID else { return }
        if hiddenBundleIDs.contains(bid) { hiddenBundleIDs.remove(bid) }
        else { hiddenBundleIDs.insert(bid) }
    }
}
