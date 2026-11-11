import AppKit
import SwiftUI

@main
struct ServeItApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ServerStore.shared

    var body: some Scene {
        Window("ServeIt", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .defaultSize(width: 900, height: 420)

        Window("ServeIt Logs", id: "logs") {
            LogsView()
                .environmentObject(store)
        }
        .defaultSize(width: 760, height: 480)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(store)
        } label: {
            Image(systemName: "server.rack")
            if !store.running.isEmpty {
                Text("\(store.running.count)")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Servers keep running from the menu bar after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Never leave python servers running after the app quits.
    func applicationWillTerminate(_ notification: Notification) {
        ServerStore.shared.stopAll()
    }
}
