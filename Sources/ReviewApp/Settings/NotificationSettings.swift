import ReviewCore
import SwiftUI
import UserNotifications

/// Settings › Notifications: which GitHub activity raises a system
/// notification, and how often to look. Being asked by name and through a
/// team are separate, since a team's requests are often someone else's.
struct NotificationSettings: View {
    private typealias Key = NotificationPreferences.Key

    @AppStorage(Key.reviewRequested.rawValue) private var reviewRequested = NotificationPreferences().reviewRequested
    @AppStorage(Key.teamReviewRequested.rawValue) private var teamReviewRequested = NotificationPreferences().teamReviewRequested
    @AppStorage(Key.assigned.rawValue) private var assigned = NotificationPreferences().assigned
    @AppStorage(Key.replies.rawValue) private var replies = NotificationPreferences().replies
    @AppStorage(Key.comments.rawValue) private var comments = NotificationPreferences().comments
    @AppStorage(Key.checkMinutes.rawValue) private var checkMinutes = NotificationPreferences().checkMinutes
    @State private var authorization: UNAuthorizationStatus?

    var body: some View {
        Form {
            Section("Requests and Assignments") {
                Toggle(isOn: $reviewRequested) {
                    Text("Asked to review by name")
                    Text("Someone requests your review directly.")
                }
                Toggle(isOn: $teamReviewRequested) {
                    Text("Asked to review through a team")
                    Text("Someone requests a review from a team you're on.")
                }
                Toggle(isOn: $assigned) {
                    Text("Assigned to you")
                    Text("You're made an assignee of a pull request.")
                }
            }
            Section("Comments") {
                Toggle(isOn: $replies) {
                    Text("Replies to you")
                    Text("Someone answers in a thread or conversation you've written in.")
                }
                Toggle(isOn: $comments) {
                    Text("Comments on your pull requests")
                    Text("Anything else someone writes on a pull request you opened.")
                }
            }
            Section {
                Picker("Check GitHub every", selection: $checkMinutes) {
                    ForEach(NotificationPreferences.checkMinuteChoices, id: \.self) { minutes in
                        Text(minutes == 1 ? "minute" : "\(minutes) minutes").tag(minutes)
                    }
                }
            } footer: {
                Text("While \(AppVariant.current.appName) is open, in the tracked repositories. Comments from apps and bots never notify.")
                    .font(Theme.Fonts.meta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            permissionSection
        }
        .formStyle(.grouped)
        .frame(width: Theme.settingsWidth, height: Theme.notificationSettingsHeight)
        .task { await updateAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await updateAuthorization() }
        }
    }

    /// Only when macOS will not show them: turned off, or never asked.
    @ViewBuilder private var permissionSection: some View {
        switch authorization {
        case .denied:
            Section {
                LabeledContent {
                    Button("Open System Settings…", action: openSystemSettings)
                } label: {
                    Label("Notifications are off for \(AppVariant.current.appName) in System Settings.", systemImage: "bell.slash")
                }
            }
        case .notDetermined:
            Section {
                LabeledContent {
                    Button("Allow…", action: requestAuthorization)
                } label: {
                    Label("\(AppVariant.current.appName) hasn't asked to show notifications yet.", systemImage: "bell.badge")
                }
            }
        default:
            EmptyView()
        }
    }

    private func updateAuthorization() async {
        authorization = await SystemNotifier.authorizationStatus()
    }

    private func requestAuthorization() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await updateAuthorization()
        }
    }

    private func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") else { return }
        NSWorkspace.shared.open(url)
    }
}
