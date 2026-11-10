import Foundation

/// The diff layout a review opens in: whichever of Diff or Split was last picked.
/// Whole File is not remembered, since the app also switches to it to reach a line.
public struct ModePreference {
    public static let key = "diffLayout"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var mode: CodeDocument.Mode {
        switch defaults.string(forKey: Self.key).flatMap(CodeDocument.Mode.init(rawValue:)) {
        case .split: .split
        default: .diff
        }
    }

    public func remember(_ mode: CodeDocument.Mode) {
        guard mode != .file else { return }
        defaults.set(mode.rawValue, forKey: Self.key)
    }
}
