import SwiftUI

/// View ▸ Actual Size, Zoom In, Zoom Out: text and controls across the
/// whole window, remembered across launches.
struct ZoomCommands: View {
    private let zoom = AppZoom.shared

    var body: some View {
        Button("Actual Size") { zoom.resetToActualSize() }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(zoom.level.isActualSize)
        // ⌘= is the unshifted key that carries "+" on most layouts — what
        // pressing "⌘+" actually sends.
        Button("Zoom In") { zoom.zoomIn() }
            .keyboardShortcut("=", modifiers: .command)
            .disabled(zoom.level.zoomedIn == nil)
        Button("Zoom Out") { zoom.zoomOut() }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(zoom.level.zoomedOut == nil)
        Divider()
    }
}
