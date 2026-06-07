import AppKit
import SwiftUI
import iUX_MacOS

public struct PopoverView: View {
    @Bindable var model: BarMasterModel
    @State private var tab: PopoverTab = .general

    public init(model: BarMasterModel) { self.model = model }

    public var body: some View {
        SettingsPopover(selection: $tab) {
            PopOutButton(windowID: BarMasterModule.windowID)
        } content: { tab in
            content(for: tab)
        }
    }

    @ViewBuilder
    private func content(for tab: PopoverTab) -> some View {
        switch tab {
        case .general: GeneralTab(model: model)
        case .items:   ItemsTab(model: model)
        case .about:   AboutTab()
        }
    }
}

// MARK: - Tabs

enum PopoverTab: String, CaseIterable, Identifiable, SettingsTab {
    case general, items, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: return "General"
        case .items:   return "Items"
        case .about:   return "About"
        }
    }
    var icon: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .items:   return "menubar.rectangle"
        case .about:   return "info.circle"
        }
    }
}

struct GeneralTab: View {
    @Bindable var model: BarMasterModel
    var body: some View {
        CardSection("General") {
            ToggleRow("Enable BarMaster",
                      subtitle: "Manage and hide menu bar items.",
                      isOn: $model.isEnabled)
        }
    }
}

struct ItemsTab: View {
    @Bindable var model: BarMasterModel

    var body: some View {
        CardSection("Menu Bar Items") {
            if model.discoveredItems.isEmpty {
                HStack {
                    Text(model.isScanning ? "Scanning…" : "No items found.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !model.isScanning {
                        Button("Scan") { model.scanItems() }
                    }
                }
            } else {
                ForEach(model.discoveredItems) { (item: MenuBarItem) in
                    MenuBarItemRow(item: item, model: model)
                }
                HStack {
                    Spacer()
                    Button(model.isScanning ? "Scanning…" : "Refresh") {
                        model.scanItems()
                    }
                    .disabled(model.isScanning)
                    .font(.callout)
                }
            }
        }
        .onAppear {
            if model.discoveredItems.isEmpty { model.scanItems() }
        }
    }
}

struct MenuBarItemRow: View {
    let item: MenuBarItem
    @Bindable var model: BarMasterModel

    var body: some View {
        HStack(spacing: 8) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.dashed")
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(item.appName).font(.callout)
                if let bid = item.bundleID {
                    Text(bid).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if item.isHideable {
                Toggle("", isOn: Binding(
                    get: { !model.isHidden(item) },
                    set: { _ in model.toggle(item) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            } else {
                Text("System").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .opacity(item.isHideable ? 1 : 0.5)
    }
}

struct AboutTab: View {
    @State private var status: String?
    @State private var checking = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        CardSection("About") {
            VStack(alignment: .leading, spacing: 10) {
                Text(BarMasterModule.displayName).font(.headline)
                Text("Version \(version)").foregroundStyle(.secondary)
                Button(checking ? "Checking…" : "Check for updates") {
                    Task { await checkForUpdates() }
                }
                .disabled(checking)
                if let status {
                    Text(status).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func checkForUpdates() async {
        checking = true
        defer { checking = false }
        do {
            let info = try await UpdateChecker.fetch(appID: "barmaster")
            status = UpdateChecker.isNewer(info.version, than: version)
                ? "Update available: \(info.version)"
                : "You're up to date."
        } catch {
            status = "Couldn't check: \(error.localizedDescription)"
        }
    }
}

// MARK: - Settings window (sidebar layout)

struct SettingsWindowView: View {
    @Bindable var model: BarMasterModel
    @State private var selection: PopoverTab? = .general

    var body: some View {
        SettingsWindow(title: BarMasterModule.displayName, selection: $selection) { tab in
            switch tab {
            case .general: GeneralTab(model: model)
            case .items:   ItemsTab(model: model)
            case .about:   AboutTab()
            }
        }
        .background(BarMasterWindowOpenerBridge())
    }
}

@MainActor
public enum BarMasterWindowOpener {
    public static var action: OpenWindowAction?

    public static func open() {
        guard let action else { NSSound.beep(); return }
        action(id: BarMasterModule.windowID)
        NSApp.activate(ignoringOtherApps: true)
        let id = BarMasterModule.windowID
        DispatchQueue.main.async {
            for window in NSApp.windows {
                guard let raw = window.identifier?.rawValue, raw.contains(id) else { continue }
                window.makeKeyAndOrderFront(nil)
                break
            }
        }
    }
}

private struct BarMasterWindowOpenerBridge: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { BarMasterWindowOpener.action = openWindow }
    }
}
