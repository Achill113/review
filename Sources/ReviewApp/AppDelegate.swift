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

    /// Clicking an answer's notification goes to that PR and that draft; an
    /// activity notification goes to the PR, and its thread if it has one.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let pullRequest = info[AnswerNotifier.pullRequestKey] as? String
        let draft = (info[AnswerNotifier.draftKey] as? String).flatMap(UUID.init(uuidString:))
        let thread = info[ActivityNotifier.threadKey] as? String
        await MainActor.run {
            NSApp.activate()
            guard let pullRequest, let model = self.model else { return }
            if let thread {
                model.reveal(pullRequest: pullRequest, thread: thread.isEmpty ? nil : thread)
            } else {
                model.reveal(pullRequest: pullRequest, draft: draft)
            }
        }
    }
}
