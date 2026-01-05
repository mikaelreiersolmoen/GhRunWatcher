import AppKit
import SwiftUI

@main
struct GhRunWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var watchManager = WatchManager()

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
