import SwiftUI

/// The Logs window: one tab per server, each showing its live console output.
struct LogsView: View {
    @EnvironmentObject private var store: ServerStore

    var body: some View {
        Group {
            if store.servers.isEmpty {
                Text("No servers yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TabView(selection: $store.logSelection) {
                    ForEach(store.servers) { server in
                        LogPane(server: server, buffer: store.logBuffer(for: server.id))
                            .tabItem { Text(server.title) }
                            .tag(Optional(server.id))
                    }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 560, minHeight: 320)
    }
}

private struct LogPane: View {
    @EnvironmentObject private var store: ServerStore
    let server: ServerEntry
    @ObservedObject var buffer: LogBuffer

    private static let bottom = "bottom"
    private var isRunning: Bool { store.isRunning(server.id) }

    var body: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if buffer.text.isEmpty {
                            Text("No output yet. Turn the server on and load a page.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(buffer.text)
                                .textSelection(.enabled)
                        }
                        Color.clear.frame(height: 1).id(Self.bottom)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
                .onChange(of: buffer.text) { _ in
                    proxy.scrollTo(Self.bottom, anchor: .bottom)
                }
                .onAppear {
                    proxy.scrollTo(Self.bottom, anchor: .bottom)
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(isRunning ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
                Text(isRunning ? "Running at \(server.url.absoluteString)" : "Stopped")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { buffer.clear() }
                    .disabled(buffer.text.isEmpty)
            }
        }
    }
}
