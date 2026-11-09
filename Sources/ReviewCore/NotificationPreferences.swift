import Foundation

/// Which GitHub activity raises a system notification, and how often to look.
/// Kept in `UserDefaults`, so Settings can bind each one with `@AppStorage`.
public struct NotificationPreferences: Equatable, Sendable {
    public enum Key: String, CaseIterable, Sendable {
        case reviewRequested = "notifyReviewRequested"
        case teamReviewRequested = "notifyTeamReviewRequested"
        case assigned = "notifyAssigned"
        case replies = "notifyReplies"
        case comments = "notifyComments"
        case checkMinutes = "activityCheckMinutes"
    }

    /// The choices Settings offers for `checkMinutes`.
    public static let checkMinuteChoices = [1, 2, 5, 15]

    public var reviewRequested = true
    /// Off by default: a team's requests are usually someone else's to take.
    public var teamReviewRequested = false
    public var assigned = true
    public var replies = true
    public var comments = true
    public var checkMinutes = 2

    public init() {}

    /// Reads what is stored, falling back to the defaults above.
    public init(defaults: UserDefaults) {
        let fallback = Self()
        func flag(_ key: Key, _ value: Bool) -> Bool {
            defaults.object(forKey: key.rawValue) as? Bool ?? value
        }
        reviewRequested = flag(.reviewRequested, fallback.reviewRequested)
        teamReviewRequested = flag(.teamReviewRequested, fallback.teamReviewRequested)
        assigned = flag(.assigned, fallback.assigned)
        replies = flag(.replies, fallback.replies)
        comments = flag(.comments, fallback.comments)
        let minutes = defaults.object(forKey: Key.checkMinutes.rawValue) as? Int ?? fallback.checkMinutes
        checkMinutes = max(1, minutes)
    }

    /// For `UserDefaults.register(defaults:)`, so `@AppStorage` and this type
    /// agree on what an untouched setting means.
    public static var registrationDefaults: [String: Any] {
        let fallback = Self()
        return [
            Key.reviewRequested.rawValue: fallback.reviewRequested,
            Key.teamReviewRequested.rawValue: fallback.teamReviewRequested,
            Key.assigned.rawValue: fallback.assigned,
            Key.replies.rawValue: fallback.replies,
            Key.comments.rawValue: fallback.comments,
            Key.checkMinutes.rawValue: fallback.checkMinutes,
        ]
    }

    public func allows(_ kind: ActivityNotice.Kind) -> Bool {
        switch kind {
        case .reviewRequested: reviewRequested
        case .teamReviewRequested: teamReviewRequested
        case .assigned: assigned
        case .reply: replies
        case .comment: comments
        }
    }

    /// Whether the comment check is worth its request.
    public var wantsComments: Bool {
        replies || comments
    }
}
