import AppKit
import ReviewKit
import ReviewSyntax
import SwiftUI

/// Centralized layout metrics + type system (SWIFTUI-RULES §2.4, §5.1).
///
/// Three rules keep this honest:
/// - **Scale** comes from the system's text styles (`.caption` → `.body` →
///   `.title2`), never a point size picked here. Each style's size is read
///   from AppKit and multiplied by the app's zoom (⌘+ / ⌘− / ⌘0), so the OS
///   still decides what "body" means and the reviewer decides how big.
/// - **Emphasis is weight; de-emphasis is color** (`.secondary` /
///   `.tertiary`), never a lighter font weight.
/// - **Anything that holds text scales with it.** Padding, column widths
///   and fixed heights go through `scaled(_:)`; window sizes, corner radii
///   and hairlines do not.
///
/// When you find yourself typing the same number a third time, it belongs
/// here as a named metric.
@MainActor
enum Theme {
    // MARK: Zoom

    /// A metric at the current zoom. Reading it inside a view body makes
    /// that view redraw when the zoom changes.
    static func scaled(_ value: CGFloat) -> CGFloat {
        value * AppZoom.shared.scale
    }

    /// A system text style's point size at the current zoom.
    static func textSize(_ style: NSFont.TextStyle) -> CGFloat {
        scaled(NSFont.preferredFont(forTextStyle: style).pointSize)
    }

    // MARK: Window
    static let windowMinWidth: CGFloat = 900
    static let windowMinHeight: CGFloat = 560
    /// Code review wants width: a file tree, code, and a comment column.
    static let windowDefaultWidth: CGFloat = 1400
    static let windowDefaultHeight: CGFloat = 860

    // MARK: Sidebar
    static var sidebarMinWidth: CGFloat { scaled(220) }
    static var sidebarIdealWidth: CGFloat { scaled(260) }
    static var sidebarMaxWidth: CGFloat { scaled(360) }
    /// Wide enough for an install command to sit on one line.
    static var toolPopoverWidth: CGFloat { scaled(380) }

    // MARK: Files column
    static var filesMinWidth: CGFloat { scaled(240) }
    static var filesIdealWidth: CGFloat { scaled(300) }
    static var filesMaxWidth: CGFloat { scaled(480) }

    // MARK: Browser
    static var scopesMinWidth: CGFloat { scaled(200) }
    static var scopesIdealWidth: CGFloat { scaled(240) }
    static var scopesMaxWidth: CGFloat { scaled(360) }
    static var browseTitleMinWidth: CGFloat { scaled(200) }
    static var browseTitleIdealWidth: CGFloat { scaled(420) }
    static var browseNarrowColumnWidth: CGFloat { scaled(70) }
    static var browseWideColumnWidth: CGFloat { scaled(130) }
    /// A person filter's login field: room for most logins, not a sentence.
    static var loginFieldWidth: CGFloat { scaled(120) }
    /// How long typing pauses before the browser searches.
    static let searchDelay = Duration.milliseconds(350)

    // MARK: Results panel
    static var resultsMinHeight: CGFloat { scaled(120) }
    static var resultsIdealHeight: CGFloat { scaled(220) }
    static var resultsMaxHeight: CGFloat { scaled(600) }
    /// The divider's drag target, much taller than the hairline it draws.
    static let dividerHitHeight: CGFloat = 8
    /// Room for a four-digit line number in a result row.
    static var resultLineNumberWidth: CGFloat { scaled(36) }
    /// A thread card's disclosure chevron.
    static var chevronWidth: CGFloat { scaled(12) }

    // MARK: Drafts inspector
    static var inspectorMinWidth: CGFloat { scaled(300) }
    static var inspectorIdealWidth: CGFloat { scaled(380) }
    static var inspectorMaxWidth: CGFloat { scaled(640) }
    static let cardCornerRadius: CGFloat = 8
    static let codeBlockCornerRadius: CGFloat = 6
    static var noteMinHeight: CGFloat { scaled(54) }
    static var noteMaxHeight: CGFloat { scaled(220) }
    /// Quoted code in a draft card is a reminder, not the code itself.
    static let maxQuotedLines = 6
    static var readingTopInset: CGFloat { scaled(28) }
    static var badgePaddingHorizontal: CGFloat { scaled(6) }
    static var badgePaddingVertical: CGFloat { scaled(1) }
    /// Room for "10." so a numbered list's text lines up.
    static var listMarkerWidth: CGFloat { scaled(16) }
    static let quoteBarWidth: CGFloat = 3

    // MARK: Hover
    static var hoverMaxWidth: CGFloat { scaled(520) }
    static var hoverMaxHeight: CGFloat { scaled(360) }

    // MARK: Post sheet
    static var postSheetWidth: CGFloat { scaled(620) }
    /// Grows with the zoom, but never past the screen it is shown on.
    static var postSheetHeight: CGFloat {
        min(scaled(640), (NSScreen.main?.visibleFrame.height ?? 800) * 0.85)
    }
    static var summaryHeight: CGFloat { scaled(90) }
    static var sheetPadding: CGFloat { scaled(20) }

    // MARK: Settings
    static let settingsWidth: CGFloat = 460
    static let settingsHeight: CGFloat = 360
    /// Taller: five switches with a line each, and the interval.
    static let notificationSettingsHeight: CGFloat = 520

    // MARK: Panes
    /// Standard horizontal inset for pane content.
    static var gutter: CGFloat { scaled(12) }
    static var spacing: CGFloat { scaled(10) }
    static var tightSpacing: CGFloat { scaled(5) }

    // MARK: Type scale
    //
    // The whole app's typography lives here so hierarchy stays consistent and
    // a future restyle lands in one place.
    @MainActor
    enum Fonts {
        /// Text with no style of its own: the default for the whole window.
        static var body: Font { .system(size: textSize(.body)) }
        /// A pull request's title in the detail column.
        static var pageTitle: Font { .system(size: textSize(.title2), weight: .semibold) }
        /// A sidebar row's primary line.
        static var rowTitle: Font { .system(size: textSize(.body), weight: .medium) }
        /// Metadata: repository names, counts, the footer line.
        static var meta: Font { .system(size: textSize(.caption1)) }
        /// A file's +/− counts: tabular figures so a column of them aligns.
        static var counts: Font { .system(size: textSize(.caption1), weight: .medium).monospacedDigit() }
        /// Source code in SwiftUI views; the code viewer itself uses
        /// `Code.font`.
        static var code: Font { .system(size: textSize(.body), design: .monospaced) }
        /// Code in result lists, a step down so a row stays one line.
        static var codeSmall: Font { .system(size: textSize(.callout), design: .monospaced) }
        /// The reviewer's own words in a draft.
        static var note: Font { body }
        /// "base", "not in PR".
        static var badge: Font { .system(size: textSize(.caption2), weight: .medium) }
        /// A sidebar section's header. Set explicitly: the sidebar list
        /// otherwise forces the system's size on headers, ignoring the zoom.
        static var sectionHeader: Font { .system(size: textSize(.subheadline), weight: .semibold) }
        /// An empty state's title: "No Drafts".
        static var emptyTitle: Font { .system(size: textSize(.title1), weight: .bold) }
        /// A panel's header: the results panel's "References · 3 results".
        static var panelTitle: Font { .system(size: textSize(.callout), weight: .semibold) }

        /// Markdown headings, scaled for a narrow column: `#` steps up from
        /// body, the rest are body text made heavier.
        static func markdownHeading(level: Int) -> Font {
            switch level {
            case 1: .system(size: textSize(.title3), weight: .semibold)
            case 2: .system(size: textSize(.headline), weight: .bold)
            default: rowTitle
            }
        }
    }

    // MARK: Code

    /// The code viewer's palette and metrics. AppKit types, because the
    /// viewer is an NSTextView; every colour is a dynamic system colour, so
    /// light and dark both come for free.
    @MainActor
    enum Code {
        /// Monospaced at the body text style's size and the app's zoom, so
        /// it tracks the system's text size rather than a number picked here.
        static var font: NSFont {
            NSFont.monospacedSystemFont(ofSize: textSize(.body), weight: .regular)
        }

        static var gutterFont: NSFont {
            NSFont.monospacedDigitSystemFont(ofSize: textSize(.callout), weight: .regular)
        }

        /// Tabs render four columns wide — Go is tab-indented throughout.
        static let tabWidth = 4
        /// Extra leading between lines; diff bands cover it, so they stay
        /// continuous.
        static var lineSpacing: CGFloat { scaled(2) }
        static var textInset: NSSize { NSSize(width: scaled(6), height: scaled(6)) }
        static var gutterPadding: CGFloat { scaled(8) }
        /// The leftmost gutter column, where a draft's bubble sits.
        static var draftMarkWidth: CGFloat { scaled(16) }
        static let draftMark = NSColor.controlAccentColor
        static let threadMark = NSColor.secondaryLabelColor
        /// How far below the viewport's top edge the "file being read" is
        /// taken from.
        static var topRowProbe: CGFloat { scaled(24) }
        /// How long the pointer rests on a symbol before its hover shows.
        static let hoverDelay = Duration.milliseconds(600)
        static var gutterColumnGap: CGFloat { scaled(6) }

        static let text = NSColor.textColor
        static let background = NSColor.textBackgroundColor

        static func color(for kind: TokenKind) -> NSColor {
            switch kind {
            case .keyword: .systemPink
            case .string: .systemRed
            case .escape: .systemOrange
            case .comment: .secondaryLabelColor
            case .number, .constant: .systemPurple
            case .type: .systemTeal
            case .function: .systemBlue
            case .property: .systemIndigo
            case .parameter: .systemBrown
            case .operator: .secondaryLabelColor
            case .tag: .systemBlue
            }
        }

        /// The full-width band behind a row. Nil for plain context.
        static func band(for kind: CodeDocument.Row.Kind) -> NSColor? {
            switch kind {
            case .added: .systemGreen.withAlphaComponent(0.14)
            case .removed: .systemRed.withAlphaComponent(0.14)
            case .hunkHeader, .gap: .quaternaryLabelColor.withAlphaComponent(0.12)
            case .filler: .quaternaryLabelColor.withAlphaComponent(0.05)
            case .fileHeader: .controlAccentColor.withAlphaComponent(0.12)
            case .context: nil
            }
        }

        /// The gutter's +/− mark, so a change never relies on colour alone.
        static func markColor(for kind: CodeDocument.Row.Kind) -> NSColor {
            switch kind {
            case .added: .systemGreen
            case .removed: .systemRed
            case .hunkHeader, .context, .gap, .filler, .fileHeader: .tertiaryLabelColor
            }
        }

        static let hunkHeaderText = NSColor.secondaryLabelColor
        /// A gap's "↑ 5 lines" and "rest of func run": clickable, so the link
        /// colour.
        static let expansionText = NSColor.linkColor
        /// A file's heading in the all-files view: the code font, bold.
        static var fileHeaderFont: NSFont {
            NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .semibold)
        }
        static let fileHeaderText = NSColor.labelColor
        static let lineNumber = NSColor.tertiaryLabelColor
        static let gutterBackground = NSColor.textBackgroundColor
        static let gutterSeparator = NSColor.separatorColor
    }
}
