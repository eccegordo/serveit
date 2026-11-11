import AppKit
import SwiftUI

/// The menu shown from ServeIt's menu bar item.
struct MenuBarContent: View {
    @EnvironmentObject private var store: ServerStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.servers.isEmpty {
            Text("No servers yet")
        } else {
            ForEach(store.servers) { server in
                let isRunning = store.isRunning(server.id)
                Menu("\(isRunning ? "●" : "○")  \(server.title)") {
                    Toggle("Running", isOn: Binding(
                        get: { isRunning },
                        set: { $0 ? store.start(server.id) : store.stop(server.id) }
                    ))
                    Button("Open in Browser") {
                        NSWorkspace.shared.open(server.url)
                    }
                    .disabled(!isRunning)
                    Button("Show Logs") {
                        store.logSelection = server.id
                        show("logs")
                    }
                }
            }
        }

        Divider()

        Button("Add New Server") {
            store.addServer()
            show("main")
        }
        Button("Stop All Servers") {
            store.stopAll()
        }
        .disabled(store.running.isEmpty)

        Divider()

        Button("Open ServeIt Window") { show("main") }
        Button("Quit ServeIt") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func show(_ windowID: String) {
        openWindow(id: windowID)
        NSApp.activate(ignoringOtherApps: true)
    }
}
