import AppKit
import ReviewCore
import UserNotifications

/// Receives what AppKit delivers outside SwiftUI: clicks on notifications.
/// (`review://` links go to the window's `onOpenURL`.)
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private weak var model: AppModel?

    func attach(_ model: AppModel) {
        self.model = model
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: Notifications

    /// Shown even while the app is active: the reviewer may be on another PR.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Clicking a notification opens what it is about, as its row in the
    /// notifications panel does, and marks it read there.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let id = (info[DeliveredNotification.Key.record] as? String).flatMap(UUID.init(uuidString:))
        let pullRequest = info[DeliveredNotification.Key.pullRequest] as? String
        let isUpdate = info[SystemNotifier.updateKey] != nil
        await MainActor.run {
            NSApp.activate()
            guard let model = self.model else { return }
            if isUpdate {
                model.updater.isSheetShown = true
            } else if let id, model.notificationLog.records.contains(where: { $0.id == id }) {
                model.openNotification(id: id)
            } else if let pullRequest {
                // Raised by an earlier build, or since dropped from the log.
                model.reveal(pullRequest: pullRequest, thread: nil)
            }
        }
    }
}
