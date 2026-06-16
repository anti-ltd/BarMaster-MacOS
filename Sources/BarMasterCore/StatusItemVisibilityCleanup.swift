import AppKit
import CoreFoundation

/// Clears persisted `NSStatusItem Visible` overrides that macOS writes when a user
/// Cmd-drags an icon off the bar. Without cleanup the item can stay hidden even
/// though `isVisible` reports true.
@MainActor
public enum StatusItemVisibilityCleanup {

    public static let barMasterAutosaveNames = [
        BarMasterModule.displayName,
        "barmaster.itemA",
        "barmaster.itemB",
    ]

    @discardableResult
    public static func clearBarMasterOverrides() -> Bool {
        clearAppDomainOverrides(names: barMasterAutosaveNames, prefix: "barmaster.")
    }

    @discardableResult
    public static func clearAppDomainOverrides(names: [String], prefix: String) -> Bool {
        let defaults = UserDefaults.standard
        var cleared = false

        for name in names {
            for keyPrefix in ["NSStatusItem Visible ", "NSStatusItem VisibleCC "] {
                let key = keyPrefix + name
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    cleared = true
                }
            }
        }

        let visiblePrefix = "NSStatusItem Visible \(prefix)"
        let visibleCCPrefix = "NSStatusItem VisibleCC \(prefix)"
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(visiblePrefix) || key.hasPrefix(visibleCCPrefix) {
                defaults.removeObject(forKey: key)
                cleared = true
            }
        }

        if clearByHostOverrides(matching: prefix) {
            cleared = true
        }

        if cleared {
            defaults.synchronize()
            CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        }
        return cleared
    }

    @discardableResult
    private static func clearByHostOverrides(matching prefix: String) -> Bool {
        let globalDomain = ".GlobalPreferences" as CFString
        guard let allKeys = CFPreferencesCopyKeyList(
            globalDomain,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? [String] else { return false }

        let keyPrefixes = [
            "NSStatusItem Visible \(prefix)",
            "NSStatusItem VisibleCC \(prefix)",
        ]
        let keysToRemove = allKeys.filter { key in
            keyPrefixes.contains { key.hasPrefix($0) }
        }
        guard !keysToRemove.isEmpty else { return false }

        for key in keysToRemove {
            CFPreferencesSetValue(
                key as CFString,
                nil,
                globalDomain,
                kCFPreferencesCurrentUser,
                kCFPreferencesCurrentHost
            )
        }
        CFPreferencesAppSynchronize(globalDomain)
        return true
    }
}
