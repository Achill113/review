import Foundation
import ReviewCore
import ReviewKit
import Testing

@Suite
struct ActivityDetectorTests {
    private let reference = PullRequestReference(owner: "acme", repository: "r", number: 1)
    private let since = Date(timeIntervalSince1970: 1_000)

    private func item(_ reasons: Set<InboxItem.Reason>, number: Int = 1) -> InboxItem {
        InboxItem(
            reference: PullRequestReference(owner: "acme", repository: "r", number: number),
            title: "Fix it", author: "dev", isDraft: false, updatedAt: since, reasons: reasons
        )
    }

    private func comment(_ author: String, at offset: TimeInterval, isBot: Bool = false) -> ActivityComment {
        ActivityComment(
            author: author, isBot: isBot, body: "said \(offset)", createdAt: since.addingTimeInterval(offset),
            url: URL(string: "https://github.com/acme/r/pull/1#c\(author)\(Int(offset))")
        )
    }

    private func activity(author: String = "dev", thread: [ActivityComment] = [], conversation: [ActivityComment] = []) -> PullRequestActivity {
        PullRequestActivity(
            reference: reference, title: "Fix it", author: author,
            threads: thread.isEmpty ? [] : [PullRequestActivity.Thread(id: "T1", comments: thread)],
            comments: conversation
        )
    }

    // MARK: Requests

    @Test("A review request by name notifies; one through a team does not by default")
    func directAndTeamRequests() {
        let inbox = [item([.reviewRequested]), item([.teamReviewRequested], number: 2)]
        let notices = ActivityDetector.requests(in: inbox, seen: [], preferences: NotificationPreferences())
        #expect(notices.map(\.kind) == [.reviewRequested])
        #expect(notices.first?.actor == "dev")
    }

    @Test("Team requests notify when turned on")
    func teamRequestsWhenOn() {
        var preferences = NotificationPreferences()
        preferences.teamReviewRequested = true
        let notices = ActivityDetector.requests(in: [item([.teamReviewRequested])], seen: [], preferences: preferences)
        #expect(notices.map(\.kind) == [.teamReviewRequested])
    }

    @Test("A PR asked of the reviewer and their team counts as asked by name")
    func directOutranksTeam() {
        var preferences = NotificationPreferences()
        preferences.teamReviewRequested = true
        let notices = ActivityDetector.requests(in: [item([.reviewRequested, .teamReviewRequested])], seen: [], preferences: preferences)
        #expect(notices.map(\.kind) == [.reviewRequested])
    }

    @Test("Assigned and asked at once is one notice, for the assignment")
    func oneNoticePerPullRequest() {
        let notices = ActivityDetector.requests(in: [item([.assigned, .reviewRequested])], seen: [], preferences: NotificationPreferences())
        #expect(notices.map(\.kind) == [.assigned])
    }

    @Test("What was there at the last look is not news; a new reason is")
    func onlyNewKeys() {
        let before = [item([.reviewRequested])]
        let seen = ActivityDetector.requestKeys(in: before)
        #expect(ActivityDetector.requests(in: before, seen: seen, preferences: NotificationPreferences()).isEmpty)
        let after = [item([.reviewRequested, .assigned])]
        #expect(ActivityDetector.requests(in: after, seen: seen, preferences: NotificationPreferences()).map(\.kind) == [.assigned])
    }

    @Test("A team request becoming a request by name is news")
    func teamToDirect() {
        let seen = ActivityDetector.requestKeys(in: [item([.teamReviewRequested])])
        let notices = ActivityDetector.requests(in: [item([.reviewRequested])], seen: seen, preferences: NotificationPreferences())
        #expect(notices.map(\.kind) == [.reviewRequested])
    }

    @Test("The reviewer's own pull requests never notify as requests")
    func ownPullRequests() {
        let notices = ActivityDetector.requests(in: [item([.authored, .assigned])], seen: [], preferences: NotificationPreferences())
        #expect(notices.isEmpty)
    }

    @Test("A turned-off kind is skipped, and does not hide one that is on")
    func preferencesFilter() {
        var preferences = NotificationPreferences()
        preferences.assigned = false
        let notices = ActivityDetector.requests(in: [item([.assigned, .reviewRequested])], seen: [], preferences: preferences)
        #expect(notices.map(\.kind) == [.reviewRequested])
    }

    // MARK: Comments

    @Test("Someone answering in a thread the viewer wrote in is a reply")
    func threadReply() {
        let pullRequest = activity(thread: [comment("me", at: -60), comment("ana", at: 30), comment("bo", at: 60)])
        let notices = ActivityDetector.comments(in: [pullRequest], viewer: "Me", since: since, seen: [], preferences: NotificationPreferences())
        #expect(notices.count == 1)
        #expect(notices.first?.kind == .reply)
        #expect(notices.first?.actor == "bo")
        #expect(notices.first?.count == 2)
        #expect(notices.first?.threadID == "T1")
    }

    @Test("A thread the viewer never wrote in, on someone else's PR, is not news")
    func unrelatedThread() {
        let pullRequest = activity(thread: [comment("ana", at: -60), comment("bo", at: 30)])
        #expect(ActivityDetector.comments(in: [pullRequest], viewer: "me", since: since, seen: [], preferences: NotificationPreferences()).isEmpty)
    }

    @Test("New comments on the viewer's own PR are one notice, about the newest")
    func commentOnOwn() {
        let pullRequest = PullRequestActivity(
            reference: reference, title: "Fix it", author: "me",
            threads: [
                PullRequestActivity.Thread(id: "T1", comments: [comment("ana", at: 30)]),
                PullRequestActivity.Thread(id: "T2", comments: [comment("ana", at: 50)]),
            ],
            comments: [comment("bo", at: 40)]
        )
        let notices = ActivityDetector.comments(in: [pullRequest], viewer: "me", since: since, seen: [], preferences: NotificationPreferences())
        #expect(notices.map(\.kind) == [.comment])
        #expect(notices.first?.count == 3)
        #expect(notices.first?.actor == "ana")
        #expect(notices.first?.threadID == "T2")
    }

    @Test("Answering the viewer in the conversation is a reply")
    func conversationReply() {
        let pullRequest = activity(conversation: [comment("me", at: -10), comment("ana", at: 30)])
        let notices = ActivityDetector.comments(in: [pullRequest], viewer: "me", since: since, seen: [], preferences: NotificationPreferences())
        #expect(notices.map(\.kind) == [.reply])
        #expect(notices.first?.threadID == nil)
    }

    @Test("Old, already seen, the viewer's own, and bots' comments never notify")
    func ignored() {
        let seen = comment("cy", at: 50)
        let pullRequest = activity(
            author: "me",
            thread: [comment("ana", at: -30), comment("me", at: 20), comment("claude", at: 40, isBot: true), seen]
        )
        let notices = ActivityDetector.comments(in: [pullRequest], viewer: "me", since: since, seen: [seen.id], preferences: NotificationPreferences())
        #expect(notices.isEmpty)
    }

    @Test("Turning off replies leaves comments on the viewer's PRs")
    func repliesOff() {
        var preferences = NotificationPreferences()
        preferences.replies = false
        let pullRequest = activity(author: "me", thread: [comment("me", at: -60), comment("ana", at: 30)], conversation: [comment("bo", at: 40)])
        let notices = ActivityDetector.comments(in: [pullRequest], viewer: "me", since: since, seen: [], preferences: preferences)
        #expect(notices.map(\.kind) == [.comment])
        #expect(notices.first?.count == 1)
    }

    @Test("A reply and a comment on the same PR are one notice each")
    func replyAndComment() {
        let pullRequest = activity(author: "me", thread: [comment("me", at: -60), comment("ana", at: 30)], conversation: [comment("bo", at: 40)])
        let notices = ActivityDetector.comments(in: [pullRequest], viewer: "me", since: since, seen: [], preferences: NotificationPreferences())
        #expect(notices.map(\.kind) == [.reply, .comment])
    }

    @Test("Remembers every comment in the window, and none before it")
    func commentIDs() {
        let pullRequest = activity(thread: [comment("ana", at: -30), comment("bo", at: 30)], conversation: [comment("cy", at: 40)])
        let ids = ActivityDetector.commentIDs(in: [pullRequest], since: since)
        #expect(ids == [comment("bo", at: 30).id, comment("cy", at: 40).id])
    }

    // MARK: Preferences and store

    @Test("Preferences read what is stored and default the rest")
    func preferences() throws {
        let defaults = try #require(UserDefaults(suiteName: "ActivityDetectorTests-\(UUID())"))
        defaults.set(true, forKey: NotificationPreferences.Key.teamReviewRequested.rawValue)
        defaults.set(5, forKey: NotificationPreferences.Key.checkMinutes.rawValue)
        let preferences = NotificationPreferences(defaults: defaults)
        #expect(preferences.teamReviewRequested)
        #expect(preferences.reviewRequested)
        #expect(preferences.checkMinutes == 5)
    }

    @Test("The store round-trips its state")
    func store() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("activity-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ActivityStore(root: root)
        #expect(store.load() == ActivityStore.State())
        let state = ActivityStore.State(requestKeys: ["acme/r#1 assigned"], commentsCheckedAt: since, seenComments: ["x"])
        try store.save(state)
        #expect(store.load() == state)
    }
}
