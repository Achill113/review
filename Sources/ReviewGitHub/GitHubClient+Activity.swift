import Foundation
import ReviewCore
import ReviewProcess

extension GitHubClient {
    /// Pull requests involving the viewer that changed since `since`, with
    /// their recent comments, and who the viewer is — one GraphQL request.
    /// Limited to `repositories` unless it is empty.
    ///
    /// Only PRs updated since are fetched, so a quiet check costs one search
    /// that matches nothing. `involves:@me` covers the viewer's own PRs and
    /// every PR they have commented on, open or not.
    public func activity(
        in repositories: [RepositoryName],
        since: Date
    ) async throws -> (viewer: String, pullRequests: [PullRequestActivity]) {
        let request = """
            query($q: String!) {
              viewer { login }
              search(query: $q, type: ISSUE, first: 25) {
                nodes {
                  ... on PullRequest {
                    number title
                    repository { nameWithOwner }
                    author { __typename login }
                    comments(last: 30) { nodes { \(Self.commentFields) } }
                    reviews(last: 30) { nodes { \(Self.commentFields) } }
                    reviewThreads(last: 50) { nodes { id comments(first: 50) { nodes { \(Self.commentFields) } } } }
                  }
                }
              }
            }
            """
        let output = try await Subprocess.run(
            gh,
            ["api", "graphql", "-f", "query=\(request)", "-f", "q=\(Self.activityQuery(in: repositories, since: since))"],
            environment: environment,
            timeout: .seconds(60)
        )
        // Partial data — one repository gone private — still decodes.
        guard let decoded = try? Self.decodeActivity(output.stdout) else {
            let detail = [output.stdoutText, output.stderrText]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            throw GitHubError.failed(status: output.status, message: detail)
        }
        return decoded
    }

    private static let commentFields = "author { __typename login } body createdAt url"

    /// `is:pr involves:@me updated:>=2026-11-09T17:00:00Z repo:… sort:updated-desc`.
    static func activityQuery(in repositories: [RepositoryName], since: Date) -> String {
        let from = ISO8601DateFormatter().string(from: since)
        let scope = repositories.map { "repo:\($0)" }
        return (["is:pr", "involves:@me", "updated:>=\(from)"] + scope + ["sort:updated-desc"]).joined(separator: " ")
    }

    static func decodeActivity(_ data: Data) throws -> (viewer: String, pullRequests: [PullRequestActivity]) {
        struct Response: Decodable {
            struct DataField: Decodable {
                let viewer: Viewer
                let search: Search
            }
            struct Viewer: Decodable { let login: String }
            struct Search: Decodable { let nodes: [Node?] }
            /// Optional throughout: a non-PR match comes back as `{}`.
            struct Node: Decodable {
                let number: Int?
                let title: String?
                let repository: Repository?
                let author: Author?
                let comments: Comments?
                let reviews: Comments?
                let reviewThreads: Threads?
            }
            struct Repository: Decodable { let nameWithOwner: String }
            struct Author: Decodable {
                let typename: String
                let login: String

                enum CodingKeys: String, CodingKey {
                    case typename = "__typename"
                    case login
                }
            }
            struct Comments: Decodable { let nodes: [Comment?] }
            struct Comment: Decodable {
                let author: Author?
                let body: String
                let createdAt: Date
                let url: URL?
            }
            struct Threads: Decodable { let nodes: [Thread?] }
            struct Thread: Decodable {
                let id: String
                let comments: Comments
            }
            let data: DataField
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(Response.self, from: data)

        func comments(_ comments: Response.Comments?) -> [ActivityComment] {
            (comments?.nodes ?? []).compactMap { node in
                node.map {
                    ActivityComment(
                        author: $0.author?.login ?? "ghost", isBot: $0.author?.typename == "Bot",
                        body: $0.body, createdAt: $0.createdAt, url: $0.url
                    )
                }
            }
        }

        let pullRequests = response.data.search.nodes.compactMap { node -> PullRequestActivity? in
            guard let node, let number = node.number, let title = node.title, let repository = node.repository,
                  let reference = try? PullRequestReference(parsing: "\(repository.nameWithOwner)#\(number)")
            else { return nil }
            let threads = (node.reviewThreads?.nodes ?? []).compactMap { thread in
                thread.map { PullRequestActivity.Thread(id: $0.id, comments: comments($0.comments)) }
            }
            // A review that only holds line comments has an empty summary;
            // its comments are in the threads.
            let conversation = comments(node.comments) + comments(node.reviews).filter {
                !$0.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return PullRequestActivity(
                reference: reference, title: title, author: node.author?.login ?? "ghost",
                threads: threads, comments: conversation
            )
        }
        return (response.data.viewer.login, pullRequests)
    }
}
