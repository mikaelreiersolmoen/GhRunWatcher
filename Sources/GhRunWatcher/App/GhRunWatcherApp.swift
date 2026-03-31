import AppKit
import SwiftUI

@main
struct GhRunWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var watchManager = WatchManager()
    private let ipcServer: IPCServer

    init() {
        let manager = WatchManager()
        _watchManager = StateObject(wrappedValue: manager)
        ipcServer = IPCServer(watchManager: manager)
        ipcServer.start()
    }

    var body: some Scene {
        MenuBarExtra {
            WatchMenuView()
                .environmentObject(watchManager)
        } label: {
            if let icon = statusBarIcon {
                Image(nsImage: icon)
            } else {
                Label("GhRunWatcher", systemImage: "eye")
            }
        }
    }

    private var statusBarIcon: NSImage? {
        guard let icon = NSImage(named: "AppIcon") else { return nil }
        icon.isTemplate = true
        icon.size = NSSize(width: 18, height: 18)
        return icon
    }
}
