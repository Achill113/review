import AppKit

/// Routes the Edit › Find commands to the code view's find bar.
///
/// The text view has its own find bar (`usesFindBar`), but its actions only
/// reach it through the responder chain — so with the file list focused, ⌘F
/// did nothing, and with the find field focused, ⌘G stopped at the scroll
/// view that holds the bar. This finds the code view the reviewer is in, or
/// the main one, and hands it the action directly.
@MainActor
enum CodeFinder {
    static func perform(_ action: NSTextFinder.Action, in window: NSWindow? = NSApp.keyWindow) {
        guard let window, let textView = target(in: window) else { return }
        // Stepping through matches leaves focus where it is in this pane —
        // the find field, usually. Anything else starts from the code.
        let isStepping = action == .nextMatch || action == .previousMatch
        if !isStepping || !owns(window.firstResponder, textView) {
            window.makeFirstResponder(textView)
        }
        textView.performTextFinderAction(Sender(tag: action.rawValue))
    }

    /// For scripting: selects the first match for `text`, makes it the
    /// search string, and opens the find bar on it — as a reviewer would with
    /// ⌘E and ⌘F. (Writing the find pasteboard alone fills the field but
    /// leaves the bar searching for its old string.)
    static func find(_ text: String, in window: NSWindow? = NSApp.keyWindow) {
        guard let window, let textView = target(in: window) else { return }
        let first = (textView.string as NSString).range(of: text)
        guard first.location != NSNotFound else { return }
        textView.setSelectedRange(first)
        perform(.setSearchString, in: window)
        perform(.showFindInterface, in: window)
        textView.scrollRangeToVisible(first)
    }

    /// The code view holding focus — itself, or its find bar — or else the
    /// main one: in a split, the head side, which is the one with comments.
    static func target(in window: NSWindow) -> CodeTextView? {
        if let focused = codeTextView(owning: window.firstResponder) { return focused }
        let all = codeTextViews(in: window.contentView)
        return all.first { $0.onAddComment != nil } ?? all.first
    }

    private static func owns(_ responder: NSResponder?, _ textView: CodeTextView) -> Bool {
        codeTextView(owning: responder) === textView
    }

    /// The code view a responder belongs to: the view itself, or anything
    /// inside its scroll view, which is where the find bar sits.
    private static func codeTextView(owning responder: NSResponder?) -> CodeTextView? {
        var view = responder as? NSView
        while let current = view {
            if let textView = current as? CodeTextView { return textView }
            if let scrollView = current as? NSScrollView, let textView = scrollView.documentView as? CodeTextView {
                return textView
            }
            view = current.superview
        }
        return nil
    }

    private static func codeTextViews(in view: NSView?) -> [CodeTextView] {
        guard let view, !view.isHiddenOrHasHiddenAncestor else { return [] }
        if let textView = view as? CodeTextView { return [textView] }
        return view.subviews.flatMap { codeTextViews(in: $0) }
    }

    /// `performTextFinderAction(_:)` reads the action from its sender's `tag`.
    private final class Sender: NSObject {
        @objc let tag: Int

        init(tag: Int) {
            self.tag = tag
        }
    }
}
