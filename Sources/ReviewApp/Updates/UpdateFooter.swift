import SwiftUI

/// A line at the foot of the sidebar while main has commits this copy lacks,
/// so a dismissed banner is not the only notice.
struct UpdateFooter: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let update = model.updater.status.update {
            Button {
                model.updater.isSheetShown = true
            } label: {
                Label(summary(update.commits.count), systemImage: "arrow.down.circle.fill")
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(.tint)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Build main and relaunch")
            .padding(.horizontal, Theme.gutter)
            .padding(.vertical, Theme.spacing)
            .background(.bar)
        }
    }

    private func summary(_ count: Int) -> String {
        switch count {
        case 0: "Update available"
        case 1: "Update available: 1 new commit"
        default: "Update available: \(count) new commits"
        }
    }
}
