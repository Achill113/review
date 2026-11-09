import SwiftUI

/// The Settings window's tabs.
struct SettingsView: View {
    enum Tab: String {
        case repositories, fileOrder, notifications
    }

    /// Stored so the file list's Edit File Order… can open its tab.
    static let tabKey = "settingsTab"
    @AppStorage(SettingsView.tabKey) private var tab = Tab.repositories

    var body: some View {
        TabView(selection: $tab) {
            RepositoriesSettings()
                .tabItem { Label("Repositories", systemImage: "tray.2") }
                .tag(Tab.repositories)
            FileOrderSettings()
                .tabItem { Label("File Order", systemImage: "list.number") }
                .tag(Tab.fileOrder)
            NotificationSettings()
                .tabItem { Label("Notifications", systemImage: "bell.badge") }
                .tag(Tab.notifications)
        }
    }
}
