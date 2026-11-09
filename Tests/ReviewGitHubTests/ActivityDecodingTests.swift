import Foundation
import ReviewCore
import Testing
@testable import ReviewGitHub

@Suite
struct ActivityDecodingTests {
    @Test("Decodes the viewer, threads, conversation and review summaries, marking bots")
    func decodes() throws {
        let json = #"""
            {"data": {"viewer": {"login": "me"}, "search": {"nodes": [
              {},
              {"number": 7, "title": "Fix it", "repository": {"nameWithOwner": "acme/r"},
               "author": {"__typename": "User", "login": "me"},
               "comments": {"nodes": [
                 {"author": {"__typename": "Bot", "login": "github-actions"}, "body": "CI", "createdAt": "2026-11-09T10:00:00Z", "url": "https://github.com/acme/r/pull/7#issuecomment-1"}
               ]},
               "reviews": {"nodes": [
                 {"author": {"__typename": "User", "login": "ana"}, "body": "", "createdAt": "2026-11-09T10:01:00Z", "url": "https://github.com/acme/r/pull/7#pullrequestreview-2"},
                 {"author": {"__typename": "User", "login": "ana"}, "body": "Looks good", "createdAt": "2026-11-09T10:02:00Z", "url": "https://github.com/acme/r/pull/7#pullrequestreview-3"}
               ]},
               "reviewThreads": {"nodes": [
                 {"id": "PRRT_1", "comments": {"nodes": [
                   {"author": null, "body": "why?", "createdAt": "2026-11-09T10:03:00Z", "url": "https://github.com/acme/r/pull/7#discussion_r4"}
                 ]}}
               ]}}
            ]}}}
            """#
        let decoded = try GitHubClient.decodeActivity(Data(json.utf8))
        #expect(decoded.viewer == "me")
        let pullRequest = try #require(decoded.pullRequests.first)
        #expect(decoded.pullRequests.count == 1)
        #expect(pullRequest.reference == PullRequestReference(owner: "acme", repository: "r", number: 7))
        #expect(pullRequest.author == "me")
        // The empty review summary is dropped; its comments are in threads.
        #expect(pullRequest.comments.map(\.author) == ["github-actions", "ana"])
        #expect(pullRequest.comments.map(\.isBot) == [true, false])
        #expect(pullRequest.threads.first?.id == "PRRT_1")
        #expect(pullRequest.threads.first?.comments.first?.author == "ghost")
    }

    @Test("Searches PRs involving the viewer, updated since, in the tracked repositories")
    func query() {
        let since = Date(timeIntervalSince1970: 1_762_682_400)
        let query = GitHubClient.activityQuery(in: [RepositoryName(owner: "acme", name: "r")], since: since)
        #expect(query == "is:pr involves:@me updated:>=2025-11-09T10:00:00Z repo:acme/r sort:updated-desc")
    }
}
