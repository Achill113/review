import Foundation
import Testing
@testable import ReviewKit

/// Runs a stand-in for `scripts/promote.sh`: the real one builds for minutes
/// and replaces /Applications/Review.app.
@Suite
struct UpdateInstallerTests {
    @Test("Returns once the build is ready, leaving the script waiting for the app to quit")
    func readyWhenBuilt() async throws {
        let fixture = try InstallerFixture.make(script: """
            echo "→ building abc1234"
            echo "pid $PROMOTE_WAIT_PID" > "$PWD/waited-for"
            touch "$PROMOTE_READY_FILE"
            sleep 3
            """)
        defer { fixture.remove() }

        try await fixture.installer().install(quittingFor: 4242)

        let waited = try String(contentsOf: fixture.source.appendingPathComponent("waited-for"), encoding: .utf8)
        #expect(waited == "pid 4242\n")
        #expect(try fixture.log().contains("→ building abc1234"))
    }

    @Test("A failed build throws with the end of the log")
    func failedBuild() async throws {
        let fixture = try InstallerFixture.make(script: """
            echo "→ building abc1234"
            echo "✗ swift build failed" >&2
            exit 3
            """)
        defer { fixture.remove() }

        let error = await #expect(throws: UpdateInstaller.Failure.self) {
            try await fixture.installer().install(quittingFor: 4242)
        }

        #expect(error?.status == 3)
        #expect(error?.logTail.contains("✗ swift build failed") == true)
    }

    @Test("Runs with the given environment, not the app's own")
    func environment() async throws {
        let fixture = try InstallerFixture.make(script: """
            echo "path $PATH"
            touch "$PROMOTE_READY_FILE"
            """)
        defer { fixture.remove() }

        try await fixture.installer(environment: ["PATH": "/login/shell/bin:/usr/bin:/bin"]).install(quittingFor: 1)

        #expect(try fixture.log().contains("path /login/shell/bin:/usr/bin:/bin"))
    }
}

private struct InstallerFixture {
    let directory: URL
    let source: URL

    var logFile: URL { directory.appendingPathComponent("logs/update.log") }

    static func make(script: String) throws -> Self {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("review-installer-\(UUID().uuidString)", isDirectory: true)
        let source = directory.appendingPathComponent("checkout", isDirectory: true)
        let scripts = source.appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        let promote = scripts.appendingPathComponent("promote.sh")
        try ("#!/usr/bin/env bash\nset -euo pipefail\n" + script + "\n").write(to: promote, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: promote.path)
        return Self(directory: directory, source: source)
    }

    func installer(environment: [String: String] = ["PATH": "/usr/bin:/bin"]) -> UpdateInstaller {
        UpdateInstaller(source: source, environment: environment, log: logFile)
    }

    func log() throws -> String {
        try String(contentsOf: logFile, encoding: .utf8)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
