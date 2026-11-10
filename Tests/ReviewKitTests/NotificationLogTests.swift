import Foundation
import ReviewCore
import ReviewKit
import Testing

@Suite
struct NotificationLogTests {
    private let reference = PullRequestReference(owner: "acme", repository: "api", number: 12)

    private func record(_ title: String, at seconds: TimeInterval, isRead: Bool = false) -> NotificationRecord {
        NotificationRecord(
            date: Date(timeIntervalSince1970: seconds), kind: .comment, reference: reference,
            title: title, subtitle: "Fix the parser", body: "", isRead: isRead
        )
    }

    @Test("Keeps records newest first")
    func newestFirst() {
        var log = NotificationLog()
        log.add([record("a", at: 1)])
        log.add([record("c", at: 3), record("b", at: 2)])
        #expect(log.records.map(\.title) == ["c", "b", "a"])
    }

    @Test("Drops the oldest past the limit")
    func limit() {
        var log = NotificationLog()
        log.add((0..<(NotificationLog.limit + 5)).map { record("\($0)", at: TimeInterval($0)) })
        #expect(log.records.count == NotificationLog.limit)
        #expect(log.records.last?.title == "5")
    }

    @Test("Counts, marks and removes")
    func readAndRemove() throws {
        var log = NotificationLog()
        log.add([record("a", at: 1), record("b", at: 2), record("c", at: 3, isRead: true)])
        #expect(log.unreadCount == 2)
        let first = try #require(log.records.first { $0.title == "a" })
        log.setRead(true, id: first.id)
        #expect(log.unreadCount == 1)
        log.markAllRead()
        #expect(log.unreadCount == 0)
        log.remove(id: first.id)
        #expect(log.records.map(\.title) == ["c", "b"])
        log.removeAll()
        #expect(log.records.isEmpty)
    }

    @Test("Survives a save and load")
    func roundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = NotificationLogStore(root: root)
        #expect(store.load().records.isEmpty)
        var log = NotificationLog()
        log.add([record("a", at: 1), record("b", at: 2, isRead: true)])
        try store.save(log)
        #expect(store.load() == log)
    }

    @Test("Words an activity notice as its banner")
    func noticeWording() {
        let reply = NotificationRecord(notice: ActivityNotice(
            kind: .reply, reference: reference, pullRequestTitle: "Fix the parser",
            actor: "ana", body: "First **point**.\n\nSecond.", count: 3, threadID: "T1"
        ))
        #expect(reply.title == "3 replies, latest from ana")
        #expect(reply.body == "First point.")
        #expect(reply.subtitle == "Fix the parser")
        #expect(reply.threadID == "T1")
        #expect(!reply.isRead)

        let request = NotificationRecord(notice: ActivityNotice(
            kind: .reviewRequested, reference: reference, pullRequestTitle: "Fix the parser", actor: "bo"
        ))
        #expect(request.title == "bo asked you to review")
        #expect(request.body == "acme/api#12")
    }

    @Test("Words Claude's answer and failure")
    func answerWording() {
        let draft = UUID()
        let answer = NotificationRecord.answer(
            pullRequest: reference, draft: draft, title: "Line 4", answer: "It parses.", isError: false
        )
        #expect(answer.kind == .answer)
        #expect(answer.title == "Claude answered")
        #expect(answer.draftID == draft)
        let failure = NotificationRecord.answer(
            pullRequest: reference, draft: nil, title: "All drafts", answer: "Timed out", isError: true
        )
        #expect(failure.kind == .answerFailed)
        #expect(failure.title == "Claude couldn't answer")
    }
}

@Suite
struct DeliveredNotificationTests {
    private func delivered(
        _ title: String,
        identifier: String = UUID().uuidString,
        info: [String: String] = [:]
    ) -> DeliveredNotification {
        DeliveredNotification(
            identifier: identifier, date: Date(timeIntervalSince1970: 100), title: title,
            subtitle: "Fix the parser", body: "Looks good",
            userInfo: ["pullRequest": "acme/api#12"].merging(info) { _, new in new }
        )
    }

    @Test("Rebuilds a record with its ID, thread and kind")
    func rebuildsCurrent() throws {
        let id = UUID()
        let record = try #require(NotificationRecord(delivered: delivered(
            "ana replied", info: ["record": id.uuidString, "thread": "T1"]
        )))
        #expect(record.id == id)
        #expect(record.kind == .reply)
        #expect(record.threadID == "T1")
        #expect(record.reference == PullRequestReference(owner: "acme", repository: "api", number: 12))
        #expect(!record.isRead)
    }

    @Test("Rebuilds an older build's notifications from their wording")
    func rebuildsOlder() throws {
        let identifier = UUID()
        let answer = try #require(NotificationRecord(delivered: delivered(
            "Claude answered", identifier: identifier.uuidString, info: ["draft": ""]
        )))
        #expect(answer.kind == .answer)
        #expect(answer.draftID == nil)
        #expect(answer.id == identifier)
        let kinds = [
            "bo asked you to review": NotificationRecord.Kind.reviewRequested,
            "bo asked your team to review": .teamReviewRequested,
            "You were assigned": .assigned,
            "3 replies, latest from ana": .reply,
            "7 comments, latest from cy": .comment,
            "Claude couldn't answer": .answerFailed,
        ]
        for (title, kind) in kinds {
            #expect(NotificationRecord(delivered: delivered(title, info: ["thread": ""]))?.kind == kind)
        }
    }

    @Test("Skips a notification that names no pull request")
    func needsPullRequest() {
        let notice = DeliveredNotification(
            identifier: "x", date: .now, title: "Hello", subtitle: "", body: "", userInfo: [:]
        )
        #expect(NotificationRecord(delivered: notice) == nil)
    }

    @Test("Adding a record already in the log keeps the log's copy")
    func noDuplicates() throws {
        let reference = PullRequestReference(owner: "acme", repository: "api", number: 12)
        let original = NotificationRecord(kind: .comment, reference: reference, title: "a", subtitle: "", body: "", isRead: true)
        var log = NotificationLog(records: [original])
        var copy = original
        copy.isRead = false
        log.add([copy])
        #expect(log.records == [original])
    }
}
