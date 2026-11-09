import Foundation

/// Something on GitHub worth a system notification.
public struct ActivityNotice: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Hashable, Sendable {
        /// Asked to review by name.
        case reviewRequested
        /// Asked to review through a team.
        case teamReviewRequested
        /// Made an assignee.
        case assigned
        /// Someone answered in a thread or conversation the reviewer wrote in.
        case reply
        /// Someone commented on the reviewer's own pull request.
        case comment
    }

    public let kind: Kind
    public let reference: PullRequestReference
    public let pullRequestTitle: String
    /// Who did it: the PR's author for a request, the commenter otherwise.
    public let actor: String
    /// The newest comment's text; empty for a request.
    public let body: String
    /// How many new comments this one notice stands for.
    public let count: Int
    /// The review thread to show when the notice is clicked.
    public let threadID: String?

    public init(
        kind: Kind,
        reference: PullRequestReference,
        pullRequestTitle: String,
        actor: String,
        body: String = "",
        count: Int = 1,
        threadID: String? = nil
    ) {
        self.kind = kind
        self.reference = reference
        self.pullRequestTitle = pullRequestTitle
        self.actor = actor
        self.body = body
        self.count = count
        self.threadID = threadID
    }
}
