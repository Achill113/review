import Foundation
import ReviewCore
import Testing

@Suite
struct BuildInfoTests {
    @Test("Reads the commit and the checkout an installed build came from")
    func readsStampedValues() {
        let info = BuildInfo(infoDictionary: ["ReviewCommit": "68b3f7c", "ReviewSource": "/Users/me/review"])

        #expect(info.commit == "68b3f7c")
        #expect(info.source == URL(fileURLWithPath: "/Users/me/review", isDirectory: true))
        #expect(info.canUpdate)
    }

    @Test("A dirty build's commit is the commit it started from")
    func stripsDirtySuffix() {
        #expect(BuildInfo(infoDictionary: ["ReviewCommit": "68b3f7c+dirty"]).commit == "68b3f7c")
    }

    @Test("Missing, empty, unknown and unsubstituted values mean it cannot update")
    func missingValues() {
        let builds = [
            BuildInfo(infoDictionary: [:]),
            BuildInfo(infoDictionary: ["ReviewCommit": "unknown", "ReviewSource": "/Users/me/review"]),
            BuildInfo(infoDictionary: ["ReviewCommit": "68b3f7c", "ReviewSource": ""]),
            BuildInfo(infoDictionary: ["ReviewCommit": "__COMMIT__", "ReviewSource": "__SOURCE__"]),
        ]

        for build in builds {
            #expect(!build.canUpdate)
        }
        #expect(builds[1].commit == nil)
        #expect(builds[2].source == nil)
        #expect(builds[3].commit == nil)
        #expect(builds[3].source == nil)
    }
}
