import Foundation
import ReviewGit
import Testing
@testable import ReviewKit

/// A real "origin" and a checkout of it, as `make install` builds from.
@Suite
struct UpdateCheckerTests {
    @Test("Up to date when origin/main is the installed commit")
    func upToDate() async throws {
        let fixture = try await UpdateFixture.make()
        defer { fixture.remove() }

        #expect(try await fixture.checker().check() == nil)
    }

    @Test("Lists the commits on origin/main since the installed one, newest first")
    func listsNewCommits() async throws {
        let fixture = try await UpdateFixture.make()
        defer { fixture.remove() }
        try await fixture.pushToOrigin("Gray the empty bell")
        let head = try await fixture.pushToOrigin("Keep notifications across relaunches")

        let update = try #require(try await fixture.checker().check())

        #expect(update.head == head)
        #expect(update.commits.map(\.subject) == ["Keep notifications across relaunches", "Gray the empty bell"])
        #expect(update.commits.first.map { head.hasPrefix($0.sha) } == true)
    }

    @Test("Ignores commits on the checkout's own branch")
    func ignoresLocalWork() async throws {
        let fixture = try await UpdateFixture.make()
        defer { fixture.remove() }
        try await fixture.checkout.git("checkout", "--quiet", "-b", "feature")
        try fixture.checkout.write("local.txt", "mine\n")
        try await fixture.checkout.git("add", "-A")
        try await fixture.checkout.git("commit", "--quiet", "-m", "local work")

        #expect(try await fixture.checker().check() == nil)
    }

    @Test("A commit main no longer has is an update with no list")
    func unknownInstalledCommit() async throws {
        let fixture = try await UpdateFixture.make()
        defer { fixture.remove() }
        let head = try await fixture.pushToOrigin("after")

        let update = try #require(try await fixture.checker(installed: "0000000").check())

        #expect(update.head == head)
        #expect(update.commits.isEmpty)
    }
}

private struct UpdateFixture {
    let directory: URL
    let origin: Shell
    let checkout: Shell
    let installed: String

    static func make() async throws -> Self {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("review-update-\(UUID().uuidString)", isDirectory: true)
        let environment = [
            "PATH": "/usr/bin:/bin", "HOME": directory.path, "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "GIT_AUTHOR_NAME": "Fixture", "GIT_AUTHOR_EMAIL": "f@example.com",
            "GIT_COMMITTER_NAME": "Fixture", "GIT_COMMITTER_EMAIL": "f@example.com",
        ]
        let originURL = directory.appendingPathComponent("origin", isDirectory: true)
        try FileManager.default.createDirectory(at: originURL, withIntermediateDirectories: true)
        let origin = Shell(directory: originURL, environment: environment)
        try await origin.git("init", "--quiet", "--initial-branch=main")
        try origin.write("README.md", "review\n")
        try await origin.git("add", "-A")
        try await origin.git("commit", "--quiet", "-m", "first")

        let checkout = Shell(directory: directory.appendingPathComponent("checkout", isDirectory: true), environment: environment)
        try await Shell(directory: directory, environment: environment).git("clone", "--quiet", originURL.path, "checkout")
        let installed = try await checkout.git("rev-parse", "--short", "HEAD")
        return Self(directory: directory, origin: origin, checkout: checkout, installed: installed)
    }

    func checker(installed: String? = nil) -> UpdateChecker {
        UpdateChecker(
            git: GitClient(git: URL(fileURLWithPath: "/usr/bin/git"), gh: nil, environment: checkout.environment),
            source: checkout.directory,
            installed: installed ?? self.installed
        )
    }

    /// Lands a commit on origin's main, as a merged pull request does; returns its full SHA.
    @discardableResult
    func pushToOrigin(_ subject: String) async throws -> String {
        try origin.write("\(UUID().uuidString).txt", subject)
        try await origin.git("add", "-A")
        try await origin.git("commit", "--quiet", "-m", subject)
        return try await origin.git("rev-parse", "HEAD")
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
