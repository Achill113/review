import AppKit
import ReviewCore
import ReviewKit
import UserNotifications

/// Shows notification records as macOS notifications. Every record is also
/// kept in the in-app panel (`AppModel.notificationLog`), so one macOS
/// suppresses is not lost.
@MainActor
enum SystemNotifier {

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

    /// Not a `NotificationRecord`: it is about the app, not a pull request,
    /// so it stays out of the panel. Clicking it opens the update sheet.
    static func post(_ update: AvailableUpdate) {
        let content = UNMutableNotificationContent()
        content.title = "A new version of \(AppVariant.current.appName) is available"
        content.body = switch update.commits.count {
        case 0: "main has moved on. Click to update."
        case 1: "1 new commit on main: \(update.commits[0].subject)"
        default: "\(update.commits.count) new commits on main, latest: \(update.commits[0].subject)"
        }
        content.sound = .default
        content.userInfo = [updateKey: update.head]
        let request = UNNotificationRequest(identifier: updateKey, content: content, trigger: nil)
        Task {
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            do {
                try await center.add(request)
            } catch {
                NSLog("Review: update notification not shown: \(error)")
            }
        }
    }

    nonisolated static let updateKey = "update"

    /// Whether macOS will show them; `UNNotificationSettings` itself is not
    /// `Sendable`, so only its status leaves here.
    nonisolated static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Takes notifications out of Notification Center as they are deleted
    /// from the panel, so the next launch does not take them back. A
    /// request's identifier is its record's ID.
    static func removeDelivered(ids: [UUID]) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids.map(\.uuidString))
    }

    static func removeAllDelivered() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// This app's notifications still in Notification Center.
    /// `UNNotification` is not `Sendable`, so only plain values leave here.
    nonisolated static func delivered() async -> [DeliveredNotification] {
        await UNUserNotificationCenter.current().deliveredNotifications().map { notification in
            let content = notification.request.content
            return DeliveredNotification(
                identifier: notification.request.identifier,
                date: notification.date,
                title: content.title,
                subtitle: content.subtitle,
                body: content.body,
                userInfo: content.userInfo.reduce(into: [:]) { info, entry in
                    if let key = entry.key as? String, let value = entry.value as? String { info[key] = value }
                }
            )
        }
    }

    private static func request(for record: NotificationRecord) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = record.title
        content.subtitle = record.subtitle
        content.body = record.body
        content.sound = .default
        content.threadIdentifier = record.reference.description
        // Enough to rebuild the record from Notification Center if the log
        // ever loses it; see `NotificationRecord(delivered:)`.
        var info = [
            DeliveredNotification.Key.record: record.id.uuidString,
            DeliveredNotification.Key.pullRequest: record.reference.description,
        ]
        if let thread = record.threadID { info[DeliveredNotification.Key.thread] = thread }
        switch record.kind {
        case .answer, .answerFailed:
            info[DeliveredNotification.Key.draft] = record.draftID?.uuidString ?? ""
        case .reviewRequested, .teamReviewRequested, .assigned, .reply, .comment:
            break
        }
        content.userInfo = info
        return UNNotificationRequest(identifier: record.id.uuidString, content: content, trigger: nil)
    }
}
