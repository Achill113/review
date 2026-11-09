import ArgumentParser
import Foundation
import ReviewCore
import ReviewKit

/// Prints what the app's notifications would say, by the same rules, as if
/// nothing had been seen yet. Reads only: the app's record is left alone.
struct Activity: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Show the review requests, replies and comments the app would notify about.",
        discussion: "Every kind is shown, including team review requests, whatever Settings says. Searches the tracked repositories."
    )

    @Option(help: "Look at comments from this many hours back.")
    var hours = 24.0

    func run() async throws {
        let services = await AppServices.start()
        let tracked = services.trackedRepositories.load()
        var everything = NotificationPreferences()
        everything.teamReviewRequested = true

        let inbox = try await services.inbox(in: tracked) ?? []
        let requests = ActivityDetector.requests(in: inbox, seen: [], preferences: everything)
        print("Requests (\(requests.count)):")
        for notice in requests { print(line(notice)) }

        let since = Date.now.addingTimeInterval(-hours * 60 * 60)
        guard let fetched = try await services.activity(in: tracked, since: since) else {
            throw ValidationError("gh is missing; run `review doctor`.")
        }
        let comments = ActivityDetector.comments(in: fetched.pullRequests, viewer: fetched.viewer, since: since, seen: [], preferences: everything)
        print("\nReplies and comments for \(fetched.viewer) in the last \(hours.formatted()) hours, from \(fetched.pullRequests.count) pull requests (\(comments.count)):")
        for notice in comments { print(line(notice)) }
    }

    private func line(_ notice: ActivityNotice) -> String {
        let count = notice.count > 1 ? " ×\(notice.count)" : ""
        let thread = notice.threadID.map { " [\($0)]" } ?? ""
        let body = notice.body.isEmpty ? "" : " — \(notice.body.prefix(70).replacingOccurrences(of: "\n", with: " "))"
        return "  \(notice.kind.rawValue)\(count)  \(notice.reference)  \(notice.actor)\(thread)\(body)"
    }
}
