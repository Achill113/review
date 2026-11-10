import Foundation
import ReviewGit

/// Commits on origin/main that the installed build does not have.
public struct AvailableUpdate: Sendable, Equatable {
    public struct Commit: Sendable, Equatable, Identifiable {
        public let sha: String
        public let subject: String

        public var id: String { sha }
    }

    /// origin/main's full SHA.
    public let head: String
    /// Newest first; empty when the installed commit is not on main.
    public let commits: [Commit]
}

/// Compares the installed build's commit with origin/main in the checkout
/// it was built from.
public struct UpdateChecker: Sendable {
    let git: GitClient
    let source: URL
    let installed: String

    public init(git: GitClient, source: URL, installed: String) {
        self.git = git
        self.source = source
        self.installed = installed
    }

    /// Nil when up to date.
    public func check() async throws -> AvailableUpdate? {
        try await git.run(["fetch", "--quiet", "origin", "main"], in: source, timeout: .seconds(120))
        let head = try await git.run(["rev-parse", "origin/main"], in: source).stdoutText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !head.hasPrefix(installed) else { return nil }
        return AvailableUpdate(head: head, commits: (try? await commits(since: installed)) ?? [])
    }

    private func commits(since installed: String) async throws -> [AvailableUpdate.Commit] {
        let log = try await git.run(["log", "--format=%h%x09%s", "\(installed)..origin/main"], in: source).stdoutText
        return log.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", maxSplits: 1)
            guard let sha = fields.first else { return nil }
            return AvailableUpdate.Commit(sha: String(sha), subject: fields.count > 1 ? String(fields[1]) : "")
        }
    }
}
