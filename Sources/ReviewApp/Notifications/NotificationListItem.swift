import ReviewCore
import SwiftUI

/// A row in the notifications panel: clicking it opens what it is about, and
/// a button beside it marks it read without opening it. An unread row always
/// shows the button; a read one shows it on hover, to mark it unread again.
struct NotificationListItem: View {
    let record: NotificationRecord
    let open: () -> Void
    let setRead: (Bool) -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: Theme.tightSpacing) {
            Button(action: open) {
                NotificationRow(record: record)
            }
            .buttonStyle(.plain)

            readButton
                .opacity(record.isRead && !isHovered ? 0 : 1)
        }
        .onHover { isHovered = $0 }
    }

    private var readButton: some View {
        Button(
            record.isRead ? "Mark as Unread" : "Mark as Read",
            systemImage: record.isRead ? "circle" : "checkmark.circle"
        ) {
            setRead(!record.isRead)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(record.isRead ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
        .font(Theme.Fonts.rowTitle)
        .help(record.isRead ? "Mark as Unread" : "Mark as Read")
    }
}
