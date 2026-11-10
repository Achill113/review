import Foundation

/// A notification still in macOS Notification Center, as plain values, so
/// the panel can take back one it never recorded: raised before the panel
/// existed, or lost to a failed save.
public struct DeliveredNotification: Hashable, Sendable {
    /// `userInfo` keys. "pullRequest", "draft" and "thread" are what builds
    /// before the panel wrote, so their notifications still come back.
    public enum Key {
        public static let record = "record"
        public static let pullRequest = "pullRequest"
        public static let thread = "thread"
        public static let draft = "draft"
    }

    public let identifier: String
    public let date: Date
    public let title: String
    public let subtitle: String
    public let body: String
    public let userInfo: [String: String]

    public init(identifier: String, date: Date, title: String, subtitle: String, body: String, userInfo: [String: String]) {
        self.identifier = identifier
        self.date = date
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.userInfo = userInfo
    }
}

extension NotificationRecord {
    /// Rebuilds a record from a notification in Notification Center; nil
    /// for one that names no pull request. Unread: nothing says it was seen.
    public init?(delivered: DeliveredNotification) {
        guard let pullRequest = delivered.userInfo[DeliveredNotification.Key.pullRequest],
              let reference = try? PullRequestReference(parsing: pullRequest)
        else { return nil }
        let id = delivered.userInfo[DeliveredNotification.Key.record].flatMap(UUID.init(uuidString:))
            ?? UUID(uuidString: delivered.identifier)
            ?? UUID()
        let thread = delivered.userInfo[DeliveredNotification.Key.thread].flatMap { $0.isEmpty ? nil : $0 }
        let draftValue = delivered.userInfo[DeliveredNotification.Key.draft]
        self.init(
            id: id,
            date: delivered.date,
            kind: Self.kind(title: delivered.title, isAnswer: draftValue != nil),
            reference: reference,
            title: delivered.title,
            subtitle: delivered.subtitle,
            body: delivered.body,
            threadID: thread,
            draftID: draftValue.flatMap(UUID.init(uuidString:))
        )
    }

    /// The kind, from the wording `init(notice:)` and `answer(…)` use. An
    /// answer about all drafts carries an empty draft value.
    private static func kind(title: String, isAnswer: Bool) -> Kind {
        if title == "Claude couldn't answer" { return .answerFailed }
        if isAnswer || title == "Claude answered" { return .answer }
        if title.hasSuffix("asked your team to review") { return .teamReviewRequested }
        if title.hasSuffix("asked you to review") { return .reviewRequested }
        if title == "You were assigned" { return .assigned }
        if title.hasSuffix(" replied") || title.contains(" replies, latest from ") { return .reply }
        return .comment
    }
}
