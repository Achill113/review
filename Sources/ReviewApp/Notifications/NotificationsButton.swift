import SwiftUI

/// The sidebar toolbar's bell: opens the notifications panel. A dot on the
/// bell while any are unread.
struct NotificationsButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let unread = model.notificationLog.unreadCount

        Button {
            model.isNotificationsShown.toggle()
        } label: {
            Label {
                Text("Notifications")
            } icon: {
                // Gray like the other toolbar icons until something is
                // unread; then the badge is red. A monochrome symbol takes
                // the first of two styles, so the empty bell gets none.
                if unread > 0 {
                    Image(systemName: "bell.badge.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.red, .primary)
                } else {
                    Image(systemName: "bell")
                }
            }
        }
        .help(unread > 0 ? "Notifications — \(unread) unread (⌥⌘N)" : "Notifications (⌥⌘N)")
        .accessibilityValue(unread > 0 ? "\(unread) unread" : "")
        .popover(isPresented: $model.isNotificationsShown, arrowEdge: .bottom) {
            NotificationsPanel()
        }
    }
}
