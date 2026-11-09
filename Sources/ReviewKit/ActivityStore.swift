import Foundation

/// What the activity check has already told the reviewer about, so a relaunch
/// neither repeats it nor misses what happened while the app was closed.
public struct ActivityStore: Sendable {
    public struct State: Codable, Equatable, Sendable {
        /// `ActivityDetector.requestKeys` from the last look; nil before the
        /// first, which records what is there without notifying.
        public var requestKeys: Set<String>?
        /// When comments were last checked, by this Mac's clock; nil before
        /// the first check, which records what is there without notifying.
        public var commentsCheckedAt: Date?
        /// Comments already looked at, by `ActivityComment.id`. Each check
        /// looks back past the last one — GitHub's search can lag a comment
        /// by a minute or two — and skips these.
        public var seenComments: Set<String>

        public init(requestKeys: Set<String>? = nil, commentsCheckedAt: Date? = nil, seenComments: Set<String> = []) {
            self.requestKeys = requestKeys
            self.commentsCheckedAt = commentsCheckedAt
            self.seenComments = seenComments
        }
    }

    public let file: URL

    public init(root: URL) {
        file = root.appendingPathComponent("activity.json")
    }

    public func load() -> State {
        guard let data = try? Data(contentsOf: file),
              let state = try? Self.decoder.decode(State.self, from: data)
        else { return State() }
        return state
    }

    public func save(_ state: State) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(state).write(to: file, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
