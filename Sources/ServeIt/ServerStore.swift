import Foundation

/// One row in the table. Only this is persisted; running state is runtime-only.
struct ServerEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var path: String
    var port: Int

    var url: URL { URL(string: "http://localhost:\(port)/")! }

    /// Short label for tabs and menus, e.g. "8000 · my-site".
    var title: String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "no folder" : (trimmed as NSString).lastPathComponent
        return "\(port) · \(name)"
    }
}

/// Console output of one server, shown live in the Logs window.
/// Only ever touched on the main thread.
final class LogBuffer: ObservableObject, @unchecked Sendable {
    private static let limit = 200_000

    @Published private(set) var text = ""

    func append(_ chunk: String) {
        text += chunk
        if text.count > Self.limit {
            text = String(text.suffix(Self.limit / 2))
        }
    }

    /// Adds a line written by ServeIt itself (start/stop markers).
    func note(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        append("— \(message) (\(time)) —\n")
    }

    func clear() { text = "" }
}

/// Keeps the most recent stderr output of a server process so we can show
/// a useful message if it dies. Also drains the pipe so python never blocks.
private final class OutputTail: @unchecked Sendable {
    private let lock = NSLock()
    private var text = ""

    func append(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        text = String((text + chunk).suffix(4000))
        lock.unlock()
    }

    var lastLine: String? {
        lock.lock()
        defer { lock.unlock() }
        return text.split(whereSeparator: \.isNewline).last.map(String.init)
    }
}

@MainActor
final class ServerStore: ObservableObject {
    static let shared = ServerStore()

    static let pythonPath = "/usr/bin/python3"
    private static let defaultsKey = "servers"
    private static let firstPort = 8000

    @Published var servers: [ServerEntry] = [] {
        didSet { save() }
    }
    @Published private(set) var running: Set<UUID> = []
    @Published private(set) var errors: [UUID: String] = [:]
    /// Which server's tab is selected in the Logs window.
    @Published var logSelection: UUID?

    private var logBuffers: [UUID: LogBuffer] = [:]
    private var processes: [UUID: Process] = [:]
    /// Identifies the current launch of a row, so a late exit notification
    /// from a previous launch can't clobber the state of a newer one.
    private var launchTokens: [UUID: UUID] = [:]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([ServerEntry].self, from: data) {
            servers = saved
        }
    }

    // MARK: - Rows

    func addServer() {
        servers.append(ServerEntry(path: "", port: nextFreePort()))
    }

    func remove(_ id: UUID) {
        stop(id)
        errors[id] = nil
        logBuffers[id] = nil
        if logSelection == id { logSelection = nil }
        servers.removeAll { $0.id == id }
    }

    func logBuffer(for id: UUID) -> LogBuffer {
        if let buffer = logBuffers[id] { return buffer }
        let buffer = LogBuffer()
        logBuffers[id] = buffer
        return buffer
    }

    func isRunning(_ id: UUID) -> Bool { running.contains(id) }

    // MARK: - Start / stop

    func start(_ id: UUID) {
        guard !isRunning(id), let server = servers.first(where: { $0.id == id }) else { return }
        errors[id] = nil

        let trimmed = server.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errors[id] = "Choose a folder to serve first."
            return
        }
        let folder = (trimmed as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            errors[id] = "Folder not found: \(folder)"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.pythonPath)
        process.arguments = [
            "-u", "-m", "http.server", String(server.port),
            "--bind", "127.0.0.1",
            "--directory", folder,
        ]
        process.standardInput = FileHandle.nullDevice

        // stdout and stderr share one pipe so the log reads like a terminal.
        let tail = OutputTail()
        let buffer = logBuffer(for: id)
        let output = Pipe()
        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                tail.append(data)
                let chunk = String(decoding: data, as: UTF8.self)
                DispatchQueue.main.async { buffer.append(chunk) }
            }
        }
        process.standardOutput = output
        process.standardError = output

        let token = UUID()
        let port = server.port
        process.terminationHandler = { finished in
            let status = finished.terminationStatus
            Task { @MainActor in
                ServerStore.shared.processEnded(id: id, token: token, port: port,
                                                status: status, lastLine: tail.lastLine)
            }
        }

        do {
            try process.run()
        } catch {
            errors[id] = "Could not start python3: \(error.localizedDescription)"
            buffer.note("Could not start python3")
            return
        }
        buffer.note("Started on port \(server.port), serving \(folder)")
        processes[id] = process
        launchTokens[id] = token
        running.insert(id)
    }

    func stop(_ id: UUID) {
        // Forget the process first so its exit isn't reported as a failure.
        launchTokens[id] = nil
        running.remove(id)
        if let process = processes.removeValue(forKey: id) {
            if process.isRunning { process.terminate() }
            logBuffers[id]?.note("Stopped")
        }
    }

    func stopAll() {
        for id in Array(processes.keys) { stop(id) }
    }

    /// Called when a server process exits on its own (i.e. not via `stop`).
    private func processEnded(id: UUID, token: UUID, port: Int, status: Int32, lastLine: String?) {
        guard launchTokens[id] == token else { return }
        launchTokens[id] = nil
        processes[id] = nil
        running.remove(id)
        // Queued behind any output still on its way to the log.
        let buffer = logBuffers[id]
        DispatchQueue.main.async { buffer?.note("Server exited with code \(status)") }

        if let lastLine, lastLine.contains("Address already in use") {
            errors[id] = "Port \(port) is already in use by another program."
        } else if let lastLine {
            errors[id] = "Server stopped: \(lastLine)"
        } else {
            errors[id] = "Server stopped unexpectedly (exit code \(status))."
        }
    }

    // MARK: - Ports

    private func nextFreePort() -> Int {
        let taken = Set(servers.map(\.port))
        var port = Self.firstPort
        while port < 65535 {
            if !taken.contains(port) && Self.isPortFree(port) { return port }
            port += 1
        }
        return port
    }

    /// True if nothing on this machine is currently listening on the port.
    private static func isPortFree(_ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
