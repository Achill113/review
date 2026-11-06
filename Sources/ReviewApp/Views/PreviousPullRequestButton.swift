import SwiftUI

/// Back to the pull request looked at before this one. Its menu lists the
/// earlier ones, most recent first, to jump further back.
struct PreviousPullRequestButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            ForEach(model.previousPullRequests, id: \.self) { reference in
                Button(model.menuTitle(for: reference)) { model.open(reference) }
            }
        } label: {
            Label("Previous Pull Request", systemImage: "arrow.uturn.backward")
        } primaryAction: {
            model.showPreviousPullRequest()
        }
        .menuIndicator(model.previousPullRequests.isEmpty ? .hidden : .visible)
        .disabled(!model.canShowPreviousPullRequest)
        .help("Back to the previous pull request (⌘[)")
    }
}
