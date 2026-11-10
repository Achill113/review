import ReviewCore
import SwiftUI

/// One notification: an unread dot, what kind it is, what happened, the pull
/// request, a preview, and when.
struct NotificationRow: View {
    let record: NotificationRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.tightSpacing) {
            Circle()
                .fill(.tint)
                .frame(width: Theme.unreadDotSize, height: Theme.unreadDotSize)
                .opacity(record.isRead ? 0 : 1)
                .accessibilityHidden(true)
            Image(systemName: symbol)
                .foregroundStyle(record.kind == .answerFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .frame(width: Theme.notificationIconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.tightSpacing) {
                    Text(record.title)
                        .font(Theme.Fonts.rowTitle)
                        .fontWeight(record.isRead ? .regular : .semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Text(record.date, format: .relative(presentation: .named))
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                Text(record.subtitle)
                    .font(Theme.Fonts.meta)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if !record.body.isEmpty, record.body != record.reference.description {
                    Text(record.body)
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                // An answer's subtitle names the PR already.
                if !record.subtitle.contains(record.reference.description) {
                    Text(record.reference.description)
                        .font(Theme.Fonts.meta)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, Theme.notificationRowPadding)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(record.isRead ? record.title : "Unread, \(record.title)")
    }

    private var symbol: String {
        switch record.kind {
        case .reviewRequested: "eye"
        case .teamReviewRequested: "person.2"
        case .assigned: "person.crop.circle.badge.checkmark"
        case .reply: "arrowshape.turn.up.left"
        case .comment: "text.bubble"
        case .answer: "sparkles"
        case .answerFailed: "exclamationmark.triangle"
        }
    }
}
