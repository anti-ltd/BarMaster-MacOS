import SwiftUI
import iUX_MacOS

@MainActor
public final class BarMasterModule: AppModule {

    // MARK: - Identity

    public static let moduleID    = "ltd.anti.barmaster"
    public static let displayName = "BarMaster"
    public static let symbolName  = "menubar.rectangle"
    public static let windowID    = "barmaster-settings"

    // MARK: - Core

    private let model: BarMasterModel

    public required init() {
        model = BarMasterModel()
    }

    public func start() {
        model.start()
    }

    public var isMuted: Bool { model.isMuted }

    // MARK: - UI

    public func settingsView() -> AnyView {
        AnyView(PopoverView(model: model))
    }

    public func windowView() -> AnyView {
        AnyView(SettingsWindowView(model: model))
    }
}
