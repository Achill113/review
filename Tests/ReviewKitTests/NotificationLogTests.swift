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
