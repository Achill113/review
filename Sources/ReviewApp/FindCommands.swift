import AppKit
import SwiftUI

/// Edit › Find, which a SwiftUI `Window` scene does not provide. Each item
/// goes to the code view's find bar.
struct FindCommands: Commands {
    @FocusedValue(\.reviewSession) private var session

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Menu("Find") {
                Button("Find…") { CodeFinder.perform(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") { CodeFinder.perform(.nextMatch) }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { CodeFinder.perform(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { CodeFinder.perform(.setSearchString) }
                    .keyboardShortcut("e", modifiers: .command)
            }
            .disabled(session?.document == nil)
        }
    }
}
