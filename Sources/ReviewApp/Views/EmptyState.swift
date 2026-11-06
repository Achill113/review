import SwiftUI

/// `ContentUnavailableView` with its fonts set from `Theme`.
///
/// Left to itself, `ContentUnavailableView` derives its sizes from the
/// environment's font in a way that runs backwards from the zoom: it shrank
/// as ⌘+ grew everything else. Fonts set on its own label and description
/// are used as given.
struct EmptyState<Actions: View>: View {
    let title: String
    let systemImage: String
    var description: String?
    @ViewBuilder var actions: Actions

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .font(Theme.Fonts.emptyTitle)
        } description: {
            if let description {
                Text(description)
                    .font(Theme.Fonts.body)
                    .textSelection(.enabled)
            }
        } actions: {
            actions
        }
    }
}

extension EmptyState where Actions == EmptyView {
    init(_ title: String, systemImage: String, description: String? = nil) {
        self.init(title: title, systemImage: systemImage, description: description) { EmptyView() }
    }
}
