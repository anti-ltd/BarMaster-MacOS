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
    private var spacer: SpacerManager?
    private var spike: SpikeController?

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

        // Single instance: a new launch wins — kill any already-running copies so
        // we never leave duplicate menu bar icons behind.
        Self.killOtherInstances()

        // STAGE 0 spike — throwaway. See SpikeController.swift.
        if args.contains("--spike") {
            NSApp.setActivationPolicy(.regular)
            let s = SpikeController()
            s.start()
            spike = s
            return
        }

        StatusItemVisibilityCleanup.clearBarMasterOverrides()

        menuBar = MenuBarController(
            symbolName: BarMasterModule.symbolName,
            accessibilityLabel: BarMasterModule.displayName,
            popoverSize: NSSize(width: 460, height: 420),
            rootView: module.settingsView(),
            clickStyle: .leftClickMenu,
            menuProvider: { [weak self] in self?.contextMenu() }
        )
        // Hide/reveal divider + chevron (macOS 26 and earlier only).
        spacer = SpacerManager(secondaryAction: { BarMasterWindowOpener.open() })
        module.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let item = self?.menuBar?.statusItemForGuidance() else { return }
            MenuBarAllowListGuidance.presentIfNeeded(for: item, appName: BarMasterModule.displayName)
        }

        let id = BarMasterModule.windowID
        DispatchQueue.main.async {
            for window in NSApp.windows where window.identifier?.rawValue.contains(id) == true {
                window.close()
            }
        }
    }

    // Terminate every other running copy of this binary (matched by bundle ID
    // and by executable path so it works for both the .app and the dev binary).
    private static func killOtherInstances() {
        let mePID = NSRunningApplication.current.processIdentifier
        let myBID = Bundle.main.bundleIdentifier
        let myExec = Bundle.main.executableURL?.resolvingSymlinksInPath()
        for app in NSWorkspace.shared.runningApplications {
            guard app.processIdentifier != mePID else { continue }
            let sameBID  = myBID != nil && app.bundleIdentifier == myBID
            let sameExec = myExec != nil && app.executableURL?.resolvingSymlinksInPath() == myExec
            if sameBID || sameExec { app.forceTerminate() }
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
