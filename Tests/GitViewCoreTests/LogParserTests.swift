import Foundation
import Testing
@testable import GitViewCore

@Suite struct LogParserTests {
    @Test func parsesAllFields() throws {
        let line = "aaa\0bbb ccc\0Ada Lovelace\01700000000\0\0Fix the thing"
        let c = try #require(LogParser.parse(line))
        #expect(c.hash == "aaa")
        #expect(c.parents == ["bbb", "ccc"])
        #expect(c.author == "Ada Lovelace")
        #expect(c.date == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(c.subject == "Fix the thing")
        #expect(c.refs.isEmpty)
    }

    @Test func rootCommitHasNoParents() throws {
        let c = try #require(LogParser.parse("aaa\0\0A\01\0\0init"))
        #expect(c.parents.isEmpty)
    }

    @Test func subjectMayContainSeparatorLikeText() throws {
        let c = try #require(LogParser.parse("aaa\0\0A\01\0\0a, b -> c"))
        #expect(c.subject == "a, b -> c")
    }

    @Test func rejectsMalformedLine() {
        #expect(LogParser.parse("") == nil)
        #expect(LogParser.parse("aaa\0bbb") == nil)
    }

    @Test func parsesRefs() {
        let refs = LogParser.parseRefs(
            "HEAD -> refs/heads/main, refs/remotes/origin/main, tag: refs/tags/v1.0, refs/heads/dev")
        #expect(refs == [
            Ref(name: "main", kind: .branch, isHead: true),
            Ref(name: "origin/main", kind: .remote, isHead: false),
            Ref(name: "v1.0", kind: .tag, isHead: false),
            Ref(name: "dev", kind: .branch, isHead: false),
        ])
    }

    @Test func parsesDetachedHead() {
        #expect(LogParser.parseRefs("HEAD, refs/heads/dev") == [
            Ref(name: "HEAD", kind: .other, isHead: true),
            Ref(name: "dev", kind: .branch, isHead: false),
        ])
    }

    @Test func dropsRemoteHeadRefs() {
        #expect(LogParser.parseRefs("refs/remotes/origin/HEAD") == [])
    }

    @Test func keepsUnknownRefsAsOther() {
        #expect(LogParser.parseRefs("refs/stash") == [Ref(name: "refs/stash", kind: .other, isHead: false)])
    }
}
