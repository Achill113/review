import Foundation
import ReviewCore
import SwiftUI

/// The app's zoom, remembered across launches.
///
/// A shared object rather than an environment value because `Theme`'s
/// fonts and metrics are static: any view body (or `NSView` drawing) that
/// reads one goes through `scale`, so Observation redraws it when the zoom
/// changes, with no per-view plumbing.
@MainActor
@Observable
final class AppZoom {
    static let shared = AppZoom()

    private(set) var level: ZoomLevel {
        didSet { saveLevel() }
    }

    /// Whether `level` is written back to defaults. Off for a scripted
    /// `--zoom`, so a snapshot does not change the reviewer's own setting.
    private var isPersistent = true
    private static let key = "zoomScale"

    var scale: CGFloat {
        CGFloat(level.scale)
    }

    /// Controls step with the text, so a button keeps fitting its label.
    var controlSize: ControlSize {
        switch level.scale {
        case ..<0.9: .small
        case ..<1.25: .regular
        case ..<1.65: .large
        default: .extraLarge
        }
    }

    private init() {
        let stored = UserDefaults.standard.double(forKey: Self.key)
        level = stored > 0 ? ZoomLevel(scale: stored) : .actualSize
    }

    func zoomIn() {
        if let next = level.zoomedIn { level = next }
    }

    func zoomOut() {
        if let next = level.zoomedOut { level = next }
    }

    func resetToActualSize() {
        level = .actualSize
    }

    /// For `--zoom`: this launch only.
    func apply(scriptedScale scale: Double) {
        isPersistent = false
        level = ZoomLevel(scale: scale)
    }

    private func saveLevel() {
        guard isPersistent else { return }
        UserDefaults.standard.set(level.scale, forKey: Self.key)
    }
}
