/// Which copy of the app this build is.
///
/// A build from a working checkout is the dev variant: its own name, bundle
/// identifier, URL scheme and data folder, so an agent testing a change never
/// touches the copy the reviewer is using. Only `make install`, which builds
/// `origin/main`, compiles the installed variant (`-D REVIEW_INSTALLED`). See
/// plans/build-system.md.
public enum AppVariant: Sendable {
    case dev
    case installed

    public static var current: AppVariant {
        #if REVIEW_INSTALLED
        .installed
        #else
        .dev
        #endif
    }

    /// The bundle's name, and the folder under Application Support.
    public var appName: String {
        switch self {
        case .dev: "Review Dev"
        case .installed: "Review"
        }
    }

    public var urlScheme: String {
        switch self {
        case .dev: "review-dev"
        case .installed: "review"
        }
    }
}
