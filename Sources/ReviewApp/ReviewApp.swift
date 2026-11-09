import ReviewCore
import SwiftUI

// Not `main.swift` — see the note in Sources/ReviewCLI/Main.swift.
@main
struct ReviewApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel()

    init() {
        UserDefaults.standard.register(defaults: NotificationPreferences.registrationDefaults)
    }

    var body: some Scene {
        // One `Window`, not a `WindowGroup`: a WindowGroup opens a new window
        // for each `review://` link, and steering it with
        // `handlesExternalEvents` made launches open two. A single Window
        // cannot be duplicated, so links land in it through `onOpenURL`.
        Window("Review", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: Theme.windowMinWidth, minHeight: Theme.windowMinHeight)
                .zoomed()
                .task {
                    delegate.attach(model)
                    await model.start(applying: .current)
                }
        }
        .defaultSize(width: Theme.windowDefaultWidth, height: Theme.windowDefaultHeight)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppVariant.current.appName)") { AboutPanel.show() }
            }
            ReviewCommands(model: model)
            CommandGroup(after: .sidebar) {
                Button("Browse Pull Requests") { model.showBrowser() }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                Button("Refresh Pull Requests") { Task { await model.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                Button("Close Merged and Closed Pull Requests") { model.closeFinished() }
                    .disabled(!model.pullRequests.contains { model.status(of: $0).isFinished })
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .task { await model.start() }
        }
    }
}
