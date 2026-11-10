import AppKit
import Foundation
import Observation
import ReviewCore
import ReviewGit
import ReviewKit
import ReviewProcess

/// Watches origin/main in the checkout `make install` built from, and
/// rebuilds from it on request. Only the installed copy has that checkout
/// stamped in; a dev build never checks.
@Observable
@MainActor
final class Updater {
    enum Phase: Equatable {
        case idle
        case checking
        case installing
        case checkFailed(String)
        case installFailed(String)
    }

    private(set) var build = BuildInfo.current
    private(set) var phase = Phase.idle
    /// Nil when up to date, or not checked yet.
    private(set) var update: AvailableUpdate?
    private(set) var lastChecked: Date?
    var isSheetShown = false

    private var environment: ToolEnvironment?
    private var polling: Task<Void, Never>?
    private var notifies = true

    static let checkInterval = Duration.seconds(60 * 60)
    private static let notifiedHeadKey = "UpdateNotifiedHead"

    var canUpdate: Bool { build.canUpdate }

    var logFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/\(AppVariant.current.appName)/update.log")
    }

    /// Checks now, then every hour, while the app runs.
    func start(environment: ToolEnvironment) {
        self.environment = environment
        guard canUpdate, polling == nil else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.check()
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    /// A scripted launch checks another build against another checkout, and
    /// never notifies.
    func startScripted(environment: ToolEnvironment, build: BuildInfo) async {
        self.environment = environment
        self.build = build
        notifies = false
        isSheetShown = true
        await check()
    }

    /// Check for Updates…: shows the sheet with the answer.
    func checkFromMenu() {
        isSheetShown = true
        Task { await check() }
    }

    func check() async {
        guard let checker, phase != .checking, phase != .installing else { return }
        phase = .checking
        do {
            update = try await checker.check()
            lastChecked = .now
            phase = .idle
            notifyIfNew()
        } catch {
            phase = .checkFailed("\(error)")
        }
    }

    /// Builds origin/main, then quits; the script installs the build and
    /// opens it once this process has gone.
    func install() async {
        guard let installer, phase != .installing else { return }
        phase = .installing
        do {
            try await installer.install(quittingFor: ProcessInfo.processInfo.processIdentifier)
            NSApp.terminate(nil)
        } catch {
            phase = .installFailed(error.logTail.isEmpty ? "The build exited with status \(error.status)." : error.logTail)
        }
    }

    func showLog() {
        NSWorkspace.shared.open(logFile)
    }

    /// Once per new head of main, so an hourly check does not repeat itself.
    private func notifyIfNew() {
        guard notifies, let update, UserDefaults.standard.string(forKey: Self.notifiedHeadKey) != update.head else { return }
        UserDefaults.standard.set(update.head, forKey: Self.notifiedHeadKey)
        SystemNotifier.post(update)
    }

    private var checker: UpdateChecker? {
        guard let environment, let source = build.source, let commit = build.commit,
              let git = environment.locate(Tool.git.executableName)
        else { return nil }
        let client = GitClient(git: git, gh: environment.locate(Tool.gh.executableName), environment: environment.variables)
        return UpdateChecker(git: client, source: source, installed: commit)
    }

    private var installer: UpdateInstaller? {
        guard let environment, let source = build.source else { return nil }
        return UpdateInstaller(source: source, environment: environment.variables, log: logFile)
    }
}
