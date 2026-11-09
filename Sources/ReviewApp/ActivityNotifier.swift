import AppKit
import ReviewCore
import UserNotifications

/// System notifications for GitHub activity: review requests, assignments,
/// replies and comments. Clicking one opens the pull request, and the thread
/// when there is one.
@MainActor
enum ActivityNotifier {
    nonisolated static let threadKey = "thread"

    static func notify(_ notices: [ActivityNotice]) {
        guard !notices.isEmpty else { return }
        Task {
            // Asked the first time there is something to show; a no-op
            // once the reviewer has answered.
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            for notice in notices {
                do {
                    try await center.add(request(for: notice))
                } catch {
                    NSLog("Review: notification not shown: \(error)")
                }
            }
        }
    }

    /// Whether macOS will show them; `UNNotificationSettings` itself is not
    /// `Sendable`, so only its status leaves here.
    nonisolated static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private nonisolated static func request(for notice: ActivityNotice) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title(for: notice)
        content.subtitle = notice.pullRequestTitle
        content.body = body(for: notice)
        content.sound = .default
        content.threadIdentifier = notice.reference.description
        content.userInfo = [
            AnswerNotifier.pullRequestKey: notice.reference.description,
            threadKey: notice.threadID ?? "",
        ]
        return UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    }

    nonisolated static func title(for notice: ActivityNotice) -> String {
        switch notice.kind {
        case .reviewRequested: "\(notice.actor) asked you to review"
        case .teamReviewRequested: "\(notice.actor) asked your team to review"
        case .assigned: "You were assigned"
        case .reply: notice.count > 1 ? "\(notice.count) replies, latest from \(notice.actor)" : "\(notice.actor) replied"
        case .comment: notice.count > 1 ? "\(notice.count) comments, latest from \(notice.actor)" : "\(notice.actor) commented"
        }
    }

    private nonisolated static func body(for notice: ActivityNotice) -> String {
        switch notice.kind {
        case .reviewRequested, .teamReviewRequested, .assigned: notice.reference.description
        case .reply, .comment: AnswerNotifier.preview(notice.body)
        }
    }
}
