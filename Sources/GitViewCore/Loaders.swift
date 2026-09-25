import Foundation

public struct LogBatch: Sendable {
    public let commits: [Commit]
    public let rows: [GraphRow]
}

/// Runs `git log` and lays out the graph as commits arrive.
public final class LogLoader: @unchecked Sendable {
    public let repo: URL
    public let args: [String]
    private let batchSize: Int
    private let cancelToken = GitCancel()

    public init(repo: URL, args: [String], batchSize: Int = 1000) {
        self.repo = repo
        self.args = args
        self.batchSize = batchSize
    }

    public static func command(_ userArgs: [String]) -> [String] {
        ["-c", "core.quotepath=false", "log", "--no-color", "--no-show-signature", "--date-order",
         "--parents", "--decorate=full", "--format=" + LogParser.format] + userArgs
    }

    public func cancel() {
        cancelToken.cancel()
    }

    /// Blocks until git exits. `onBatch` runs on the calling thread.
    public func run(onBatch: (LogBatch) -> Void) -> GitResult {
        var layout = GraphLayout()
        var commits: [Commit] = []
        var rows: [GraphRow] = []
        let result = Git.stream(Self.command(args), in: repo, cancel: cancelToken) { line in
            guard let c = LogParser.parse(line) else {
                Log.error("unparsable log line: \(line.prefix(200))")
                return true
            }
            commits.append(c)
            rows.append(layout.add(hash: c.hash, parents: c.parents))
            if commits.count >= batchSize {
                onBatch(LogBatch(commits: commits, rows: rows))
                commits.removeAll(keepingCapacity: true)
                rows.removeAll(keepingCapacity: true)
            }
            return true
        }
        if !commits.isEmpty { onBatch(LogBatch(commits: commits, rows: rows)) }
        return result
    }
}

public enum DetailsLoader {
    static let format = "commit %H%nParents: %P%nAuthor: %an <%ae>%nDate: %ad%nCommitter: %cn <%ce>%nCommitDate: %cd%n%n%w(0,4,4)%B"

    public static func command(hash: String) -> [String] {
        ["-c", "core.quotepath=false", "show", "--no-color", "--no-ext-diff", "--no-show-signature",
         "--src-prefix=a/", "--dst-prefix=b/", "--date=iso-local", "--format=" + format, hash, "--"]
    }

    public static func load(repo: URL, hash: String, cancel: GitCancel? = nil,
                            maxLines: Int = 50_000) -> (CommitDetails, GitResult) {
        var parser = DetailsParser(maxLines: maxLines)
        let result = Git.stream(command(hash: hash), in: repo, cancel: cancel) { parser.add($0) }
        return (parser.finish(), result)
    }
}
