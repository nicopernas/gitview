import Foundation
import Testing
@testable import GitViewCore

@Suite struct LocalChangesTests {
    @Test func cleanTreeHasNoRows() throws {
        let repo = try TestRepo()
        try repo.commit("one")
        #expect(LocalChanges.load(repo: repo.url, args: []).isEmpty)
    }

    @Test func unstagedChangesAreAChildOfHead() throws {
        let repo = try TestRepo()
        let head = try repo.commit("one")
        try repo.write("file.txt", "changed\n")

        let rows = LocalChanges.load(repo: repo.url, args: [])
        #expect(rows.map(\.hash) == [LocalChanges.unstaged])
        #expect(rows[0].parents == [head])
        #expect(rows[0].subject == "Local uncommitted changes, not checked in to index")
    }

    @Test func stagedChangesAreAChildOfHead() throws {
        let repo = try TestRepo()
        let head = try repo.commit("one")
        try repo.write("file.txt", "changed\n")
        try repo.git("add", "file.txt")

        let rows = LocalChanges.load(repo: repo.url, args: [])
        #expect(rows.map(\.hash) == [LocalChanges.staged])
        #expect(rows[0].parents == [head])
        #expect(rows[0].subject == "Local changes checked in to index but not committed")
    }

    @Test func unstagedRowSitsOnTopOfStagedRow() throws {
        let repo = try TestRepo()
        let head = try repo.commit("one")
        try repo.write("file.txt", "staged\n")
        try repo.git("add", "file.txt")
        try repo.write("file.txt", "unstaged\n")

        let rows = LocalChanges.load(repo: repo.url, args: [])
        #expect(rows.map(\.hash) == [LocalChanges.unstaged, LocalChanges.staged])
        #expect(rows[0].parents == [LocalChanges.staged])
        #expect(rows[1].parents == [head])
    }

    @Test func pathsAfterDoubleDashLimitTheCheck() throws {
        let repo = try TestRepo()
        try repo.commit("a", file: "a.txt")
        try repo.commit("b", file: "b.txt")
        try repo.write("b.txt", "changed\n")

        #expect(LocalChanges.load(repo: repo.url, args: ["--", "a.txt"]).isEmpty)
        #expect(LocalChanges.load(repo: repo.url, args: ["--", "b.txt"]).count == 1)
    }

    @Test func fileListLabel() {
        #expect(LocalChanges.fileListLabel(LocalChanges.unstaged) == "Unstaged changes")
        #expect(LocalChanges.fileListLabel(LocalChanges.staged) == "Staged changes")
        #expect(LocalChanges.fileListLabel("0123abc") == "Commit")
    }

    @Test func emptyRepoHasNoRows() throws {
        let repo = try TestRepo()
        try repo.write("file.txt", "new\n")
        try repo.git("add", "file.txt")
        #expect(LocalChanges.load(repo: repo.url, args: []).isEmpty)
    }
}
