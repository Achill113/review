/// Back and forward through the things a reviewer has looked at, the way a
/// browser does for pages — the pull requests selected in the sidebar.
///
/// Visiting something new after going back drops what was ahead. Removing an
/// item (a closed PR) takes it out of both directions.
public struct VisitHistory<Item: Hashable & Sendable>: Sendable {
    /// Earlier visits, the most recent last.
    public private(set) var back: [Item] = []
    /// Visits gone back from, the next one last.
    public private(set) var forward: [Item] = []
    public private(set) var current: Item?

    /// How many visits each direction keeps.
    public let limit: Int

    public init(limit: Int = 50) {
        self.limit = limit
    }

    public var canGoBack: Bool { !back.isEmpty }
    public var canGoForward: Bool { !forward.isEmpty }

    /// Records a move to `item`. Nothing changes when it is already current;
    /// a move to nothing (no selection) forgets the current item without
    /// recording it.
    public mutating func visit(_ item: Item?) {
        guard item != current else { return }
        if let current, item != nil {
            back.append(current)
            if back.count > limit { back.removeFirst(back.count - limit) }
        }
        forward.removeAll()
        current = item
    }

    /// The previous item, now current; nil when there is none.
    public mutating func goBack() -> Item? {
        guard let previous = back.popLast() else { return nil }
        if let current { forward.append(current) }
        current = previous
        return previous
    }

    /// The next item, now current; nil when there is none.
    public mutating func goForward() -> Item? {
        guard let next = forward.popLast() else { return nil }
        if let current { back.append(current) }
        current = next
        return next
    }

    /// Forgets every visit to `item`. When it was current, the one before it
    /// (or else after it) becomes current and is returned, so closing the PR
    /// on screen returns to the one the reviewer came from.
    @discardableResult
    public mutating func remove(_ item: Item) -> Item? {
        back = Self.collapsingRepeats(back.filter { $0 != item })
        forward = Self.collapsingRepeats(forward.filter { $0 != item })
        if current == item {
            current = back.popLast() ?? forward.popLast()
        }
        // A neighbour equal to the current item would be a step that goes nowhere.
        if let current {
            if back.last == current { back.removeLast() }
            if forward.last == current { forward.removeLast() }
        }
        return current
    }

    /// `a, b, b, a` as `a, b, a`: removing what sat between two visits to
    /// the same item would otherwise leave a step that goes nowhere.
    private static func collapsingRepeats(_ items: [Item]) -> [Item] {
        items.enumerated().filter { $0.offset == 0 || items[$0.offset - 1] != $0.element }.map(\.element)
    }
}
