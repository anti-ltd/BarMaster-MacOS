import SwiftUI

@MainActor
@Observable
public final class BarMasterModel {

    /// Whether BarMaster is actively managing the menu bar.
    public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "isEnabled") }
    }

    /// Bundle IDs whose menu bar items are hidden.
    public var hiddenBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenBundleIDs), forKey: "hiddenBundleIDs")
        }
    }

    public init() {
        isEnabled = UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true
        let stored = UserDefaults.standard.array(forKey: "hiddenBundleIDs") as? [String] ?? []
        hiddenBundleIDs = Set(stored)
    }

    public var isMuted: Bool { !isEnabled }

    public func start() {
        // Wire up NSStatusItem observer and apply stored hidden state.
    }

    public func hide(bundleID: String) {
        hiddenBundleIDs.insert(bundleID)
    }

    public func show(bundleID: String) {
        hiddenBundleIDs.remove(bundleID)
    }

    public func toggle(bundleID: String) {
        if hiddenBundleIDs.contains(bundleID) { show(bundleID: bundleID) }
        else { hide(bundleID: bundleID) }
    }
}
