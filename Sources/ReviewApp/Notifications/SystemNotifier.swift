import AppKit
import ReviewCore
import UserNotifications

/// Shows notification records as macOS notifications. Every record is also
/// kept in the in-app panel (`AppModel.notificationLog`), so one macOS
/// suppresses is not lost.
@MainActor
enum SystemNotifier {
    nonisolated static let recordKey = "record"
    nonisolated static let pullRequestKey = "pullRequest"

    /// Asked the first time there is about to be something to show, rather
    /// than at launch; a no-op once the reviewer has answered.
    static func requestPermission() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }

    static func post(_ records: [NotificationRecord]) {
        guard !records.isEmpty else { return }
        let requests = records.map(request(for:))
        // The async form, not the completion handler: a closure written here
        // inherits @MainActor, UserNotifications calls it on its own queue,
        // and Swift's isolation check traps.
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            for request in requests {
                do {
                    try await center.add(request)
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

    private static func request(for record: NotificationRecord) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = record.title
        content.subtitle = record.subtitle
        content.body = record.body
        content.sound = .default
        content.threadIdentifier = record.reference.description
        content.userInfo = [
            recordKey: record.id.uuidString,
            pullRequestKey: record.reference.description,
        ]
        return UNNotificationRequest(identifier: record.id.uuidString, content: content, trigger: nil)
    }
}
