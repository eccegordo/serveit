import AppKit
import SwiftUI

private enum Column {
    static let toggle: CGFloat = 52
    static let port: CGFloat = 64
    static let open: CGFloat = 150
    static let logs: CGFloat = 80
    static let remove: CGFloat = 32
}

struct ContentView: View {
    @EnvironmentObject private var store: ServerStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.servers.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach($store.servers) { $server in
                            ServerRow(server: $server)
                            Divider()
                        }
                    }
                }
            }

            Divider()
            footer
        }
        .frame(minWidth: 820, minHeight: 320)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("On").frame(width: Column.toggle, alignment: .leading)
            Text("Folder").frame(maxWidth: .infinity, alignment: .leading)
            Text("Port").frame(width: Column.port, alignment: .leading)
            Text("Open").frame(width: Column.open, alignment: .leading)
            Text("Logs").frame(width: Column.logs, alignment: .leading)
            Spacer().frame(width: Column.remove)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("No servers yet")
                .font(.headline)
            Text("Add a server, pick a folder, and switch it on.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button {
                store.addServer()
            } label: {
                Label("Add New Server", systemImage: "plus")
            }
            Spacer()
            Text("\(store.running.count) of \(store.servers.count) running")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

private struct ServerRow: View {
    @EnvironmentObject private var store: ServerStore
    @Environment(\.openWindow) private var openWindow
    @Binding var server: ServerEntry

    private var isRunning: Bool { store.isRunning(server.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Toggle("Server on", isOn: Binding(
                    get: { isRunning },
                    set: { $0 ? store.start(server.id) : store.stop(server.id) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .frame(width: Column.toggle, alignment: .leading)

                HStack(spacing: 6) {
                    TextField("Folder to serve, e.g. ~/Sites/my-page", text: $server.path)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        chooseFolder()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Choose a folder…")
                }
                .disabled(isRunning)
                .frame(maxWidth: .infinity)

                Text(String(server.port))
                    .monospacedDigit()
                    .foregroundStyle(isRunning ? .primary : .secondary)
                    .frame(width: Column.port, alignment: .leading)

                Button {
                    NSWorkspace.shared.open(server.url)
                } label: {
                    Label("Open in Browser", systemImage: "safari")
                }
                .disabled(!isRunning)
                .help(isRunning ? server.url.absoluteString : "Turn the server on first")
                .frame(width: Column.open, alignment: .leading)

                Button {
                    store.logSelection = server.id
                    openWindow(id: "logs")
                } label: {
                    Label("Logs", systemImage: "terminal")
                }
                .help("Show this server's console output")
                .frame(width: Column.logs, alignment: .leading)

                Button(role: .destructive) {
                    store.remove(server.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove this server")
                .frame(width: Column.remove)
            }

            if let error = store.errors[server.id] {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, Column.toggle + 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Serve This Folder"
        if panel.runModal() == .OK, let url = panel.url {
            server.path = url.path
        }
    }
}
