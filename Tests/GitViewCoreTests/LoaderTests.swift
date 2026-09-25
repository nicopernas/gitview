import Foundation
import Testing
@testable import GitViewCore

private func loadAll(_ repo: TestRepo, _ args: [String] = []) -> ([Commit], [GraphRow], GitResult) {
    var commits: [Commit] = []
    var rows: [GraphRow] = []
    let result = LogLoader(repo: repo.url, args: args).run { batch in
        commits += batch.commits
        rows += batch.rows
    }
    return (commits, rows, result)
}

@Suite struct GitTests {
    @Test func streamsLinesAndCapturesExitCode() throws {
        let repo = try TestRepo()
        try repo.commit("one")
        try repo.commit("two")
        var lines: [String] = []
        let r = Git.stream(["log", "--format=%s"], in: repo.url) { lines.append($0); return true }
        #expect(r.status == 0)
        #expect(lines == ["two", "one"])
    }

    @Test func stopsWhenCallbackReturnsFalse() throws {
        let repo = try TestRepo()
        for i in 0..<5 { try repo.commit("c\(i)") }
        var lines: [String] = []
        _ = Git.stream(["log", "--format=%s"], in: repo.url) { lines.append($0); return false }
        #expect(lines == ["c4"])
    }

    @Test func capturesStderrOnFailure() throws {
        let repo = try TestRepo()
        try repo.commit("one")
        let r = Git.run(["log", "--no-such-flag"], in: repo.url)
        #expect(r.status != 0)
        #expect(r.stderr.contains("no-such-flag"))
    }

    @Test func runCollectsStdout() throws {
        let repo = try TestRepo()
        let hash = try repo.commit("one")
        #expect(Git.run(["rev-parse", "HEAD"], in: repo.url).stdout == hash + "\n")
    }
}

@Suite struct LogLoaderTests {
    @Test func loadsBranchesAndMerges() throws {
        let repo = try TestRepo()
        try repo.commit("base")
        try repo.git("checkout", "-q", "-b", "feature")
        try repo.commit("feature work", file: "feature.txt")
        try repo.git("checkout", "-q", "main")
        try repo.commit("main work", file: "main.txt")
        try repo.git("merge", "-q", "--no-edit", "feature")

        let (commits, rows, result) = loadAll(repo)
        #expect(result.status == 0)
        #expect(commits.count == 4)
        #expect(rows.count == 4)
        #expect(commits[0].parents.count == 2)
        #expect(commits[0].refs.contains(Ref(name: "main", kind: .branch, isHead: true)))
        #expect(commits.map(\.subject).contains("feature work"))
        #expect(commits.last?.subject == "base")
        #expect(rows.map(\.width).max() == 2)
    }

    @Test func userArgsArePassedToGit() throws {
        let repo = try TestRepo()
        try repo.commit("base")
        try repo.git("checkout", "-q", "-b", "feature")
        try repo.commit("feature work")
        try repo.git("checkout", "-q", "main")

        #expect(loadAll(repo).0.count == 1)
        #expect(loadAll(repo, ["--all"]).0.count == 2)
    }

    @Test func pathFilterKeepsHistoryConnected() throws {
        let repo = try TestRepo()
        try repo.commit("a1", file: "a.txt")
        try repo.commit("b1", file: "b.txt")
        try repo.commit("a2", file: "a.txt")

        let (commits, _, _) = loadAll(repo, ["--", "a.txt"])
        #expect(commits.map(\.subject) == ["a2", "a1"])
        #expect(commits[0].parents == [commits[1].hash])
    }

    @Test func badArgsReportGitError() throws {
        let repo = try TestRepo()
        try repo.commit("base")
        let (commits, _, result) = loadAll(repo, ["no-such-branch"])
        #expect(commits.isEmpty)
        #expect(result.status != 0)
        #expect(!result.stderr.isEmpty)
    }

    @Test func deliversSeveralBatches() throws {
        let repo = try TestRepo()
        for i in 0..<5 { try repo.commit("c\(i)") }
        var sizes: [Int] = []
        _ = LogLoader(repo: repo.url, args: [], batchSize: 2).run { sizes.append($0.commits.count) }
        #expect(sizes == [2, 2, 1])
    }
}

@Suite struct DetailsLoaderTests {
    @Test func loadsHeaderAndDiff() throws {
        let repo = try TestRepo()
        try repo.commit("first", file: "a.txt", content: "old\n")
        let hash = try repo.commit("second line\n\nbody text", file: "a.txt", content: "new\n")

        let (d, r) = DetailsLoader.load(repo: repo.url, hash: hash)
        #expect(r.status == 0)
        #expect(d.text.hasPrefix("commit \(hash)\n"))
        #expect(d.text.contains("Author: Test Author <author@example.com>"))
        #expect(d.text.contains("    body text"))
        #expect(d.files.map(\.path) == ["a.txt"])
        #expect(d.spans.contains { $0.kind == .added })
        #expect(d.spans.contains { $0.kind == .removed })
    }

    @Test func reportsUnknownCommit() throws {
        let repo = try TestRepo()
        try repo.commit("first")
        let (_, r) = DetailsLoader.load(repo: repo.url, hash: "0123456789abcdef0123456789abcdef01234567")
        #expect(r.status != 0)
    }
}
