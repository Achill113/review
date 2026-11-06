import SwiftUI

/// Sets the zoomed default font and control size for everything inside, so
/// text and controls with no style of their own follow ⌘+ and ⌘− too.
struct ZoomModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.body)
            .controlSize(AppZoom.shared.controlSize)
    }
}

extension View {
    func zoomed() -> some View {
        modifier(ZoomModifier())
    }
}
