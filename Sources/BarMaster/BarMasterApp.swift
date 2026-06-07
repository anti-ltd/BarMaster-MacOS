import AppKit
import SwiftUI
import iUX_MacOS
import BarMasterCore

@main
struct BarMasterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window(BarMasterModule.displayName, id: BarMasterModule.windowID) {
            appDelegate.module.windowView()
                .onAppear  { NSApp.setActivationPolicy(.regular) }
                .onDisappear { NSApp.setActivationPolicy(.accessory) }
        }
        .defaultSize(width: 740, height: 580)
        .windowToolbarStyle(.unified)

        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let module = BarMasterModule()
    private var menuBar: MenuBarController?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--icon"), idx + 1 < args.count {
            AppIconRenderer.run(directory: args[idx + 1])
            NSApp.terminate(nil)
            return
        }

        menuBar = MenuBarController(
            symbolName: BarMasterModule.symbolName,
            accessibilityLabel: BarMasterModule.displayName,
            popoverSize: NSSize(width: 460, height: 420),
            rootView: module.settingsView(),
            clickStyle: .leftClickMenu,
            menuProvider: { [weak self] in self?.contextMenu() }
        )
        module.start()

        let id = BarMasterModule.windowID
        DispatchQueue.main.async {
            for window in NSApp.windows where window.identifier?.rawValue.contains(id) == true {
                window.close()
            }
        }
    }

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings", action: #selector(menuSettings), keyEquivalent: ",")
        settings.target = self
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit", action: #selector(menuQuit), keyEquivalent: "q")
        quit.target = self
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quit)
        return menu
    }

    @objc private func menuSettings() { BarMasterWindowOpener.open() }
    @objc private func menuQuit() { NSApplication.shared.terminate(nil) }
}
