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
                Image(systemName: unread > 0 ? "bell.badge.fill" : "bell")
                    .symbolRenderingMode(unread > 0 ? .palette : .monochrome)
                    .foregroundStyle(.red, .primary)
            }
        }
        .help(unread > 0 ? "Notifications — \(unread) unread (⌥⌘N)" : "Notifications (⌥⌘N)")
        .accessibilityValue(unread > 0 ? "\(unread) unread" : "")
        .popover(isPresented: $model.isNotificationsShown, arrowEdge: .bottom) {
            NotificationsPanel()
        }
    }
}
