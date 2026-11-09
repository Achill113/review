import Foundation

/// Recent comments on one pull request, for deciding what to notify about.
public struct PullRequestActivity: Hashable, Sendable {
    /// A review thread: comments on lines of the diff, oldest first.
    public struct Thread: Hashable, Sendable {
        public let id: String
        public let comments: [ActivityComment]

        public init(id: String, comments: [ActivityComment]) {
            self.id = id
            self.comments = comments
        }
    }

    public let reference: PullRequestReference
    public let title: String
    public let author: String
    public let threads: [Thread]
    /// Conversation comments and reviews' summaries, which are not threaded.
    public let comments: [ActivityComment]

    public init(reference: PullRequestReference, title: String, author: String, threads: [Thread], comments: [ActivityComment]) {
        self.reference = reference
        self.title = title
        self.author = author
        self.threads = threads
        self.comments = comments
    }

    /// Every comment, threaded or not.
    public var allComments: [ActivityComment] {
        threads.flatMap(\.comments) + comments
    }
}
