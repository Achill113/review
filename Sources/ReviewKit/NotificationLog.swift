import Foundation
import ReviewCore

/// Every notification the app has raised, newest first, for the in-app
/// panel. Keeps the most recent `limit`.
public struct NotificationLog: Codable, Equatable, Sendable {
    public static let limit = 200

    public private(set) var records: [NotificationRecord]

    public init(records: [NotificationRecord] = []) {
        self.records = records
    }

    public var unreadCount: Int {
        records.count { !$0.isRead }
    }

    /// Adds new records at the top, newest first, dropping the oldest past
    /// the limit.
    public mutating func add(_ new: [NotificationRecord]) {
        records = Array((new + records).sorted { $0.date > $1.date }.prefix(Self.limit))
    }

    public mutating func setRead(_ isRead: Bool, id: NotificationRecord.ID) {
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].isRead = isRead
    }

    public mutating func markAllRead() {
        for index in records.indices { records[index].isRead = true }
    }

    public mutating func remove(id: NotificationRecord.ID) {
        records.removeAll { $0.id == id }
    }

    public mutating func removeAll() {
        records = []
    }
}
