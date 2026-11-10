import Foundation

/// The notifications panel's history on disk, so it survives a relaunch.
public struct NotificationLogStore: Sendable {
    public let file: URL

    public init(root: URL) {
        file = root.appendingPathComponent("notifications.json")
    }

    public func load() -> NotificationLog {
        guard let data = try? Data(contentsOf: file),
              let log = try? Self.decoder.decode(NotificationLog.self, from: data)
        else { return NotificationLog() }
        return log
    }

    public func save(_ log: NotificationLog) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(log).write(to: file, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
