import Foundation
import Testing
@testable import BarMasterCore

@MainActor
@Test func derivedMenuBarHeightIsPositive() {
    let height = MenuBarCapabilities.derivedMenuBarHeight()
    #expect(height > 0)
}

@MainActor
@Test func spacerHideUnsupportedOnMacOS27Plus() {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    if version.majorVersion >= 27 {
        #expect(MenuBarCapabilities.spacerHideSupported == false)
        #expect(MenuBarCapabilities.limitationMessage != nil)
    }
}

@MainActor
@Test func unifiedMenuBarDetectedOnMacOS27Plus() {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    if version.majorVersion >= 27 {
        #expect(MenuBarCapabilities.usesUnifiedMenuBarWindow == true)
    }
}
