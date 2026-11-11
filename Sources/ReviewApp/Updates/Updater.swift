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
    private(set) var build = BuildInfo.current
    private(set) var status = UpdateStatus()
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
                await self?.check(.scheduled)
                try? await Task.sleep(for: Self.checkInterval)
            }
        }
    }

    /// A scripted launch checks another build against another checkout, and
    /// never notifies or installs.
    func startScripted(environment: ToolEnvironment, build: BuildInfo) async {
        self.environment = environment
        self.build = build
        notifies = false
        status.canInstall = false
        isSheetShown = true
        await check(.requested)
    }

    /// Check for Updates…: shows the sheet with the answer.
    func checkFromMenu() {
        isSheetShown = true
        Task { await check(.requested) }
    }

    func perform(_ action: UpdateStatus.Action) async {
        switch action {
        case .install, .retryInstall: await install()
        case .retryCheck: await check(.requested)
        }
    }

    /// Before startup has the environment this does nothing: `start` checks as soon as it does.
    func check(_ reason: UpdateStatus.CheckReason) async {
        guard canUpdate, let environment, status.allowsCheck(reason) else { return }
        guard let checker = checker(in: environment) else {
            status.phase = .checkFailed("git was not found, so main could not be fetched.")
            return
        }
        status.phase = .checking
        do {
            status.update = try await checker.check()
            status.hasChecked = true
            status.phase = .idle
            notifyIfNew()
        } catch {
            status.phase = .checkFailed("\(error)")
        }
    }

    /// Builds origin/main, then quits; the script installs the build and
    /// opens it once this process has gone.
    func install() async {
        guard status.canInstall, let installer, status.phase != .installing else { return }
        status.phase = .installing
        do {
            try await installer.install(quittingFor: ProcessInfo.processInfo.processIdentifier)
        } catch {
            status.phase = .installFailed(error.logTail.isEmpty ? "The build exited with status \(error.status)." : error.logTail)
            return
        }
        await quit()
    }

    /// AppKit ignores `terminate` while a sheet is attached, and Update and Relaunch is in one.
    private func quit() async {
        isSheetShown = false
        for _ in 0..<40 where NSApp.windows.contains(where: { $0.attachedSheet != nil }) {
            try? await Task.sleep(for: .milliseconds(50))
        }
        NSApp.terminate(nil)
        let name = AppVariant.current.appName
        status.phase = .installFailed("\(name) did not quit. The new build installs if you quit \(name) within five minutes.")
        isSheetShown = true
    }

    func showLog() {
        NSWorkspace.shared.open(logFile)
    }

    /// Once per new head of main, so an hourly check does not repeat itself.
    private func notifyIfNew() {
        guard notifies, let update = status.update, UserDefaults.standard.string(forKey: Self.notifiedHeadKey) != update.head else { return }
        UserDefaults.standard.set(update.head, forKey: Self.notifiedHeadKey)
        SystemNotifier.post(update)
    }

    private func checker(in environment: ToolEnvironment) -> UpdateChecker? {
        guard let source = build.source, let commit = build.commit, let git = environment.locate(Tool.git.executableName)
        else { return nil }
        let client = GitClient(git: git, gh: environment.locate(Tool.gh.executableName), environment: environment.variables)
        return UpdateChecker(git: client, source: source, installed: commit)
    }

    private var installer: UpdateInstaller? {
        guard let environment, let source = build.source else { return nil }
        return UpdateInstaller(source: source, environment: environment.variables, log: logFile)
    }
}
