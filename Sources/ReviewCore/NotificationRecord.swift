import Foundation

/// One notification the app raised, kept for the in-app notifications panel
/// whether or not macOS showed it.
public struct NotificationRecord: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case reviewRequested
        case teamReviewRequested
        case assigned
        case reply
        case comment
        /// Claude answered a draft, or all of them.
        case answer
        /// Claude was asked and could not answer.
        case answerFailed
    }

    public let id: UUID
    public let date: Date
    public let kind: Kind
    public let reference: PullRequestReference
    /// "ana replied", "Claude answered".
    public let title: String
    /// The pull request's title, or the draft's.
    public let subtitle: String
    /// A preview of what was written; the reference for a request.
    public let body: String
    /// The review thread to show when it is opened.
    public let threadID: String?
    /// The draft to show when it is opened; nil with `answer` means the
    /// answer about all drafts.
    public let draftID: UUID?
    public var isRead: Bool

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        kind: Kind,
        reference: PullRequestReference,
        title: String,
        subtitle: String,
        body: String,
        threadID: String? = nil,
        draftID: UUID? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.reference = reference
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.threadID = threadID
        self.draftID = draftID
        self.isRead = isRead
    }
}

extension NotificationRecord {
    /// The record of an activity notice, worded as its banner is.
    public init(notice: ActivityNotice, date: Date = .now) {
        let kind: Kind
        let title: String
        let body: String
        switch notice.kind {
        case .reviewRequested:
            kind = .reviewRequested
            title = "\(notice.actor) asked you to review"
            body = notice.reference.description
        case .teamReviewRequested:
            kind = .teamReviewRequested
            title = "\(notice.actor) asked your team to review"
            body = notice.reference.description
        case .assigned:
            kind = .assigned
            title = "You were assigned"
            body = notice.reference.description
        case .reply:
            kind = .reply
            title = notice.count > 1 ? "\(notice.count) replies, latest from \(notice.actor)" : "\(notice.actor) replied"
            body = Self.preview(notice.body)
        case .comment:
            kind = .comment
            title = notice.count > 1 ? "\(notice.count) comments, latest from \(notice.actor)" : "\(notice.actor) commented"
            body = Self.preview(notice.body)
        }
        self.init(
            date: date,
            kind: kind,
            reference: notice.reference,
            title: title,
            subtitle: notice.pullRequestTitle,
            body: body,
            threadID: notice.threadID
        )
    }

    /// The record of Claude's answer to a draft (`draft`), or to all of them
    /// (nil).
    public static func answer(
        pullRequest: PullRequestReference,
        draft: UUID?,
        title: String,
        answer: String,
        isError: Bool,
        date: Date = .now
    ) -> Self {
        Self(
            date: date,
            kind: isError ? .answerFailed : .answer,
            reference: pullRequest,
            title: isError ? "Claude couldn't answer" : "Claude answered",
            subtitle: title,
            body: preview(answer),
            draftID: draft
        )
    }

    /// Markdown's first paragraph, without its punctuation, cut at 220
    /// characters.
    public static func preview(_ markdown: String) -> String {
        let first = markdown.components(separatedBy: "\n\n")
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? markdown
        let plain = first.replacingOccurrences(of: "`", with: "").replacingOccurrences(of: "**", with: "")
        return plain.count > 220 ? String(plain.prefix(220)) + "…" : plain
    }
}
