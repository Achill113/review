/// Where the updater stands, and what that allows next.
public struct UpdateStatus: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case idle
        case checking
        case installing
        case checkFailed(String)
        case installFailed(String)
    }

    public enum CheckReason: Sendable {
        /// The hourly check.
        case scheduled
        /// Someone asked: the menu command or Try Again.
        case requested
    }

    public enum Action: Sendable, Equatable {
        case install
        case retryInstall
        case retryCheck
    }

    public var phase: Phase
    /// Nil when up to date, or when no check has answered yet.
    public var update: AvailableUpdate?
    public var hasChecked: Bool
    /// False for a scripted launch, which must never replace the installed copy.
    public var canInstall: Bool

    public init(phase: Phase = .idle, update: AvailableUpdate? = nil, hasChecked: Bool = false, canInstall: Bool = true) {
        self.phase = phase
        self.update = update
        self.hasChecked = hasChecked
        self.canInstall = canInstall
    }

    public var primaryAction: Action? {
        switch phase {
        case .checkFailed: .retryCheck
        case .installFailed: .retryInstall
        case .idle, .checking, .installing: update == nil ? nil : .install
        }
    }

    public var isPrimaryActionEnabled: Bool {
        guard phase != .checking, phase != .installing else { return false }
        switch primaryAction {
        case .install, .retryInstall: return canInstall
        case .retryCheck: return true
        case nil: return false
        }
    }

    /// True until a check has said whether there is an update.
    public var isAwaitingAnswer: Bool {
        guard update == nil, !hasChecked else { return false }
        switch phase {
        case .idle, .checking: return true
        case .installing, .checkFailed, .installFailed: return false
        }
    }

    public func allowsCheck(_ reason: CheckReason) -> Bool {
        switch phase {
        case .checking, .installing: false
        case .installFailed: reason == .requested
        case .idle, .checkFailed: true
        }
    }
}
