import Foundation

/// What `build.sh` stamped into Info.plist about where this build came from.
public struct BuildInfo: Sendable, Equatable {
    /// The short commit, without `+dirty`; nil when unknown.
    public let commit: String?
    /// The checkout `make install` built from; only the installed copy has one.
    public let source: URL?

    public init(infoDictionary: [String: Any]) {
        commit = Self.stamped(infoDictionary["ReviewCommit"]).map { $0.replacingOccurrences(of: "+dirty", with: "") }
        source = Self.stamped(infoDictionary["ReviewSource"]).map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    public static var current: Self {
        Self(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    public var canUpdate: Bool {
        commit != nil && source != nil
    }

    private static func stamped(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty, value != "unknown", !value.hasPrefix("__") else { return nil }
        return value
    }
}
