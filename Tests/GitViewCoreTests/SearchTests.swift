import Foundation
import Testing
@testable import GitViewCore

private func commit(_ hash: String, _ author: String, _ subject: String) -> Commit {
    Commit(hash: hash, parents: [], author: author, date: Date(), subject: subject, refs: [])
}

@Suite struct SearchTests {
    let commits = [
        commit("a1b2", "Ada", "Fix parser"),
        commit("c3d4", "Bob", "Add graph"),
        commit("e5f6", "Ada", "fix graph colors"),
    ]

    @Test func findsNextMatchAfterStart() {
        #expect(Search.find("fix", in: commits, from: 0, forward: true) == 2)
    }

    @Test func wrapsAround() {
        #expect(Search.find("fix", in: commits, from: 2, forward: true) == 0)
    }

    @Test func searchesBackward() {
        #expect(Search.find("graph", in: commits, from: 2, forward: false) == 1)
        #expect(Search.find("graph", in: commits, from: 1, forward: false) == 2)
    }

    @Test func returnsStartWhenItIsTheOnlyMatch() {
        #expect(Search.find("parser", in: commits, from: 0, forward: true) == 0)
    }

    @Test func noSelectionStartsAtTop() {
        #expect(Search.find("ada", in: commits, from: -1, forward: true) == 0)
    }

    @Test func matchesAuthorIgnoringCase() {
        #expect(Search.find("bob", in: commits, from: 0, forward: true) == 1)
    }

    @Test func matchesHashPrefixOnly() {
        #expect(Search.find("C3", in: commits, from: 0, forward: true) == 1)
        #expect(Search.find("d4", in: commits, from: 0, forward: true) == nil)
    }

    @Test func noMatchOrEmptyQueryReturnsNil() {
        #expect(Search.find("zzz", in: commits, from: 0, forward: true) == nil)
        #expect(Search.find("", in: commits, from: 0, forward: true) == nil)
        #expect(Search.find("fix", in: [], from: -1, forward: true) == nil)
    }
}

@Suite struct FileFilterTests {
    let files = [
        FileEntry(path: "Sources/App/Main.swift", location: 0),
        FileEntry(path: "README.md", location: 10),
        FileEntry(path: "Tests/MainTests.swift", location: 20),
    ]

    @Test func emptyQueryKeepsAllFiles() {
        #expect(Search.files(files, matching: "") == files)
    }

    @Test func matchesSubstringIgnoringCase() {
        #expect(Search.files(files, matching: "main").map(\.path) == ["Sources/App/Main.swift", "Tests/MainTests.swift"])
        #expect(Search.files(files, matching: "readme").map(\.path) == ["README.md"])
    }

    @Test func noMatchGivesEmptyList() {
        #expect(Search.files(files, matching: "zzz").isEmpty)
    }
}
