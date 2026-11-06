import Foundation

/// How large the app draws its text and controls, as a factor of the
/// system's own sizes: View ▸ Zoom In / Zoom Out / Actual Size.
///
/// Zooming steps through a fixed ladder, like a browser, so ⌘+ then ⌘−
/// always lands back where it started.
public struct ZoomLevel: Hashable, Sendable {
    /// Below three quarters the caption text is unreadable; above double,
    /// a code line no longer fits a laptop screen.
    public static let steps: [Double] = [0.75, 0.85, 1, 1.15, 1.3, 1.5, 1.75, 2]
    public static let actualSize = Self(scale: 1)

    public let scale: Double

    /// Clamped to the ladder's ends; a stored value between steps is kept,
    /// and the next zoom snaps it onto the ladder.
    public init(scale: Double) {
        let lowest = Self.steps.first ?? 1
        let highest = Self.steps.last ?? 1
        self.scale = scale.isFinite ? min(max(scale, lowest), highest) : 1
    }

    /// The next step up, or nil at the largest.
    public var zoomedIn: Self? {
        Self.steps.first { $0 > scale + Self.tolerance }.map(Self.init(scale:))
    }

    /// The next step down, or nil at the smallest.
    public var zoomedOut: Self? {
        Self.steps.last { $0 < scale - Self.tolerance }.map(Self.init(scale:))
    }

    public var isActualSize: Bool {
        abs(scale - 1) < Self.tolerance
    }

    /// Doubles read back from defaults may be a hair off a step.
    private static let tolerance = 0.001
}
