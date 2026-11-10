import Foundation

/// Runs `scripts/promote.sh` from the checkout the installed build came from.
///
/// The script outlives the app: once its build is ready it waits for the app
/// to quit, replaces it and opens the new one. So its output goes to a log
/// file, never a pipe — a pipe with no reader left kills it with SIGPIPE.
public struct UpdateInstaller: Sendable {
    public struct Failure: Error, Sendable {
        public let status: Int32
        public let logTail: String
    }

    let source: URL
    let environment: [String: String]
    public let log: URL

    public init(source: URL, environment: [String: String], log: URL) {
        self.source = source
        self.environment = environment
        self.log = log
    }

    /// Returns when the new build is ready and the script is waiting for
    /// `pid` to exit; the caller then quits.
    public func install(quittingFor pid: Int32) async throws(Failure) {
        let ready = log.deletingLastPathComponent().appendingPathComponent("update-ready-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: ready) }
        let process: Process
        do {
            process = try start(readyFile: ready, quittingFor: pid)
        } catch {
            throw Failure(status: -1, logTail: "\(error)")
        }
        while true {
            if FileManager.default.fileExists(atPath: ready.path) { return }
            if !process.isRunning {
                if FileManager.default.fileExists(atPath: ready.path) { return }
                throw Failure(status: process.terminationStatus, logTail: logTail())
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func start(readyFile: URL, quittingFor pid: Int32) throws -> Process {
        try FileManager.default.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try FileHandle(forWritingTo: log)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [source.appendingPathComponent("scripts/promote.sh").path]
        process.currentDirectoryURL = source
        process.environment = environment.merging([
            "PROMOTE_WAIT_PID": String(pid),
            "PROMOTE_READY_FILE": readyFile.path,
        ]) { _, promote in promote }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        try process.run()
        try? output.close()
        return process
    }

    private func logTail(lines: Int = 20) -> String {
        let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        return text.split(separator: "\n", omittingEmptySubsequences: false).suffix(lines).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
