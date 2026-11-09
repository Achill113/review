import Foundation

/// A comment on a pull request, as the activity check sees it: a thread
/// comment, a conversation comment, or a review's summary.
public struct ActivityComment: Hashable, Sendable {
    public let author: String
    /// Apps — CI, Claude, Copilot — whose comments never notify.
    public let isBot: Bool
    public let body: String
    public let createdAt: Date
    public let url: URL?

    /// Stable across checks: GitHub's URL for the comment.
    public var id: String {
        url?.absoluteString ?? "\(author) \(createdAt.timeIntervalSince1970)"
    }

    public init(author: String, isBot: Bool = false, body: String, createdAt: Date, url: URL? = nil) {
        self.author = author
        self.isBot = isBot
        self.body = body
        self.createdAt = createdAt
        self.url = url
    }
}
