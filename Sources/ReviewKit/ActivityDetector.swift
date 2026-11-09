import Foundation
import ReviewCore

/// Decides what is new since the last look. Pure, so the rules are tested
/// without GitHub; `AppModel` fetches, asks, and remembers.
public enum ActivityDetector {
    // MARK: Requests and assignments

    /// Why the reviewer is waiting on each PR, as keys like
    /// `owner/repo#12 assigned`. The next look compares against these:
    /// a key that was not there before is news. A key that goes away and
    /// comes back — asked to review again — is news again.
    public static func requestKeys(in inbox: [InboxItem]) -> Set<String> {
        Set(inbox.flatMap { item in requestKinds(of: item).map { key(item.reference, $0) } })
    }

    /// One notice per pull request with something new the reviewer wants to
    /// hear about — being assigned outranks being asked by name, which
    /// outranks a team being asked.
    public static func requests(
        in inbox: [InboxItem],
        seen: Set<String>,
        preferences: NotificationPreferences
    ) -> [ActivityNotice] {
        inbox.compactMap { item in
            let kind = requestKinds(of: item).first { kind in
                preferences.allows(kind) && !seen.contains(key(item.reference, kind))
            }
            return kind.map {
                ActivityNotice(kind: $0, reference: item.reference, pullRequestTitle: item.title, actor: item.author)
            }
        }
    }

    /// In order of importance. Asked by name implies nothing about teams, and
    /// a PR asked of the reviewer and their team is asked by name.
    static func requestKinds(of item: InboxItem) -> [ActivityNotice.Kind] {
        guard !item.isAuthored else { return [] }
        var kinds: [ActivityNotice.Kind] = []
        if item.reasons.contains(.assigned) { kinds.append(.assigned) }
        if item.reasons.contains(.reviewRequested) {
            kinds.append(.reviewRequested)
        } else if item.reasons.contains(.teamReviewRequested) {
            kinds.append(.teamReviewRequested)
        }
        return kinds
    }

    private static func key(_ reference: PullRequestReference, _ kind: ActivityNotice.Kind) -> String {
        "\(reference) \(kind.rawValue)"
    }

    // MARK: Replies and comments

    /// Comments newer than `since`, not in `seen`, by someone other than the
    /// viewer and not by an app:
    ///
    /// - a **reply** where the viewer wrote earlier in the same thread, or
    ///   earlier in the conversation;
    /// - a **comment** on the viewer's own pull request otherwise.
    ///
    /// At most one of each per pull request, about the newest — a review with
    /// five line comments is one notification, not five — counting the rest.
    public static func comments(
        in activity: [PullRequestActivity],
        viewer: String,
        since: Date,
        seen: Set<String>,
        preferences: NotificationPreferences
    ) -> [ActivityNotice] {
        let isNew = { (comment: ActivityComment) in comment.createdAt > since && !seen.contains(comment.id) }
        return activity.flatMap { pullRequest in
            let isOwn = pullRequest.author.caseInsensitiveCompare(viewer) == .orderedSame
            let threads = pullRequest.threads.compactMap { thread in
                news(in: thread.comments, threadID: thread.id, isOwn: isOwn, viewer: viewer, isNew: isNew)
            }
            let conversation = news(in: pullRequest.comments, threadID: nil, isOwn: isOwn, viewer: viewer, isNew: isNew)
            let wanted = (threads + [conversation].compactMap(\.self)).filter { preferences.allows($0.kind) }
            return ActivityNotice.Kind.allCases.compactMap { kind -> ActivityNotice? in
                let ofKind = wanted.filter { $0.kind == kind }
                guard let newest = ofKind.max(by: { $0.latest.createdAt < $1.latest.createdAt }) else { return nil }
                return ActivityNotice(
                    kind: kind, reference: pullRequest.reference, pullRequestTitle: pullRequest.title,
                    actor: newest.latest.author, body: newest.latest.body,
                    count: ofKind.reduce(0) { $0 + $1.count }, threadID: newest.threadID
                )
            }
        }
    }

    /// What is new in one thread, or one conversation.
    private struct News {
        let kind: ActivityNotice.Kind
        let latest: ActivityComment
        let count: Int
        let threadID: String?
    }

    private static func news(
        in comments: [ActivityComment],
        threadID: String?,
        isOwn: Bool,
        viewer: String,
        isNew: (ActivityComment) -> Bool
    ) -> News? {
        let isViewer = { (comment: ActivityComment) in comment.author.caseInsensitiveCompare(viewer) == .orderedSame }
        let fresh = comments
            .filter { isNew($0) && !$0.isBot && !isViewer($0) }
            .sorted { $0.createdAt < $1.createdAt }
        guard let latest = fresh.last else { return nil }
        let hasViewerWritten = comments.contains { isViewer($0) && $0.createdAt < latest.createdAt }
        let kind: ActivityNotice.Kind
        if hasViewerWritten {
            kind = .reply
        } else if isOwn {
            kind = .comment
        } else {
            return nil
        }
        return News(kind: kind, latest: latest, count: fresh.count, threadID: threadID)
    }

    /// The comments the next check should not notify about again: every one
    /// newer than `since`. Older ones fall outside its window anyway.
    public static func commentIDs(in activity: [PullRequestActivity], since: Date) -> Set<String> {
        Set(activity.flatMap(\.allComments).filter { $0.createdAt > since }.map(\.id))
    }
}
