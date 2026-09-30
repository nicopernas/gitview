import Foundation
import Testing
@testable import GitViewCore

@Suite struct WorktreesTests {
    static let porcelain = """
        worktree /repos/main
        HEAD 3e37f2f716d5e5d548d9b4e9be2fa7cac972f53f
        branch refs/heads/main

        worktree /repos/bare.git
        bare

        worktree /repos/det
        HEAD 3e37f2f716d5e5d548d9b4e9be2fa7cac972f53f
        detached
        locked testing

        worktree /repos/gone
        HEAD 3e37f2f716d5e5d548d9b4e9be2fa7cac972f53f
        branch refs/heads/nico/gone
        prunable gitdir file points to non-existent location

        """

    static func wt(_ name: String, prunable: Bool = false) -> Worktree {
        Worktree(path: "/repos/\(name)", branch: name, head: "abc", prunable: prunable)
    }

    @Test func parsesBranchDetachedAndPrunableSkippingBare() {
        let list = Worktrees.parse(Self.porcelain)
        #expect(list.map(\.path) == ["/repos/main", "/repos/det", "/repos/gone"])
        #expect(list.map(\.branch) == ["main", nil, "nico/gone"])
        #expect(list.map(\.prunable) == [false, false, true])
    }

    @Test func titleShowsBranchOrShortHash() {
        let list = Worktrees.parse(Self.porcelain)
        #expect(list.map(\.title) == ["main (main)", "det (detached 3e37f2f)", "gone (nico/gone)"])
    }

    @Test func loadsFromRepo() throws {
        let repo = try TestRepo()
        try repo.commit("one")
        try repo.git("worktree", "add", "-q", "feat-wt", "-b", "feat")

        let list = Worktrees.load(repo: repo.url)
        #expect(list.map(\.branch) == ["main", "feat"])
        #expect(Worktrees.find(repo.url.appendingPathComponent("feat-wt"), in: list) == 1)
    }

    @Test func findResolvesSymlinks() throws {
        let repo = try TestRepo()
        try repo.commit("one")
        let list = Worktrees.load(repo: repo.url)
        // TestRepo lives under /var, which git reports as /private/var.
        #expect(list[0].path != repo.url.path)
        #expect(Worktrees.find(repo.url, in: list) == 0)
    }

    @Test func fallbackIsFirstWorktreeStillOnDisk() throws {
        let repo = try TestRepo()
        try repo.commit("one")
        try repo.git("worktree", "add", "-q", "feat-wt", "-b", "feat")
        let wt = repo.url.appendingPathComponent("feat-wt")
        let list = Worktrees.load(repo: repo.url)

        #expect(Worktrees.fallback(for: wt, in: list) == nil)
        try FileManager.default.removeItem(at: wt)
        #expect(Worktrees.fallback(for: wt, in: list) == list[0])
    }

    @Test func nextWrapsAroundAndSkipsPrunable() {
        let list = [Self.wt("a"), Self.wt("b", prunable: true), Self.wt("c")]
        let a = URL(fileURLWithPath: "/repos/a")
        let c = URL(fileURLWithPath: "/repos/c")
        #expect(Worktrees.next(from: a, in: list, step: 1)?.path == "/repos/c")
        #expect(Worktrees.next(from: a, in: list, step: -1)?.path == "/repos/c")
        #expect(Worktrees.next(from: c, in: list, step: 1)?.path == "/repos/a")
    }

    @Test func nextIsNilWithOneUsableWorktree() {
        let list = [Self.wt("a"), Self.wt("b", prunable: true)]
        #expect(Worktrees.next(from: URL(fileURLWithPath: "/repos/a"), in: list, step: 1) == nil)
    }
}
