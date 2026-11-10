import AppKit
import ReviewCore
import ReviewKit
import SwiftUI

/// What is new on main, and the button that builds and installs it.
struct UpdateSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let updater = model.updater
        let status = updater.status

        VStack(alignment: .leading, spacing: Theme.spacing) {
            HStack(alignment: .top, spacing: Theme.gutter) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: Theme.updateIconSize, height: Theme.updateIconSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.tightSpacing) {
                    Text(title(updater))
                        .font(Theme.Fonts.rowTitle)
                        .bold()
                    Text(message(updater))
                        .font(Theme.Fonts.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if let commits = status.update?.commits, !commits.isEmpty, !isFailed(status) {
                CommitList(commits: commits)
            }
            if case .installFailed(let log) = status.phase {
                FailureLog(text: log)
            }
            if updater.canUpdate, isBusy(status) {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            HStack {
                if status.phase == .installing || isInstallFailed(status) {
                    Button("Show Log") { updater.showLog() }
                }
                Spacer()
                buttons(updater)
            }
        }
        .padding(Theme.sheetPadding)
        .frame(width: Theme.updateSheetWidth)
    }

    @ViewBuilder
    private func buttons(_ updater: Updater) -> some View {
        let status = updater.status
        if updater.canUpdate, let action = status.primaryAction {
            Button("Later", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(status.phase == .installing)
            Button(label(action)) {
                Task { await updater.perform(action) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!status.isPrimaryActionEnabled)
            .help(status.canInstall ? "" : "A scripted launch never installs")
        } else {
            Button("OK") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private func label(_ action: UpdateStatus.Action) -> String {
        switch action {
        case .install: "Update and Relaunch"
        case .retryInstall, .retryCheck: "Try Again"
        }
    }

    private func isBusy(_ status: UpdateStatus) -> Bool {
        status.phase == .installing || status.phase == .checking || status.isAwaitingAnswer
    }

    private func isFailed(_ status: UpdateStatus) -> Bool {
        switch status.phase {
        case .checkFailed, .installFailed: true
        case .idle, .checking, .installing: false
        }
    }

    private func isInstallFailed(_ status: UpdateStatus) -> Bool {
        if case .installFailed = status.phase { true } else { false }
    }

    private func title(_ updater: Updater) -> String {
        let name = AppVariant.current.appName
        let status = updater.status
        guard updater.canUpdate else { return "Updates are not checked in this copy" }
        guard !status.isAwaitingAnswer else { return "Checking for updates…" }
        switch status.phase {
        case .checkFailed: return "Couldn’t check for updates"
        case .installing: return "Updating \(name)…"
        case .installFailed: return "The update failed"
        case .idle, .checking: break
        }
        return status.update == nil ? "\(name) is up to date" : "A new version of \(name) is available"
    }

    private func message(_ updater: Updater) -> String {
        guard updater.canUpdate else {
            return "Only the copy installed by make install knows the checkout it was built from."
        }
        let status = updater.status
        let installed = updater.build.commit ?? "?"
        guard !status.isAwaitingAnswer else { return "Fetching main." }
        switch status.phase {
        case .checkFailed(let error):
            return error
        case .installing:
            return "Building main. \(AppVariant.current.appName) will quit and reopen when the build is ready, in a minute or two."
        case .installFailed:
            return "Nothing was installed. The end of the build log:"
        case .idle, .checking:
            break
        }
        guard let update = status.update else { return "You have the latest commit on main (\(installed))." }
        return switch update.commits.count {
        case 0: "main has moved on from the commit you have (\(installed))."
        case 1: "1 new commit on main since \(installed)."
        default: "\(update.commits.count) new commits on main since \(installed)."
        }
    }
}

private struct CommitList: View {
    let commits: [AvailableUpdate.Commit]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.tightSpacing) {
                ForEach(commits) { commit in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.spacing) {
                        Text(commit.sha)
                            .font(Theme.Fonts.codeSmall)
                            .foregroundStyle(.secondary)
                        Text(commit.subject)
                            .font(Theme.Fonts.body)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(commit.subject)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(Theme.spacing)
        }
        .frame(maxHeight: Theme.updateCommitsMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background, in: .rect(cornerRadius: Theme.codeBlockCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.codeBlockCornerRadius).strokeBorder(.separator))
    }
}

private struct FailureLog: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .font(Theme.Fonts.codeSmall)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.spacing)
        }
        .frame(maxHeight: Theme.updateCommitsMaxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .background(.background, in: .rect(cornerRadius: Theme.codeBlockCornerRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.codeBlockCornerRadius).strokeBorder(.separator))
    }
}
