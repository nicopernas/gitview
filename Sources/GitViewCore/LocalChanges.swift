import Foundation

/// gitk-style rows for changes not yet committed.
public enum LocalChanges {
    /// gitk's fake ids.
    public static let unstaged = "0000000000000000000000000000000000000000"
    public static let staged = "0000000000000000000000000000000000000001"

    public static func isLocal(_ hash: String) -> Bool {
        hash == unstaged || hash == staged
    }

    static func subject(_ hash: String) -> String {
        hash == unstaged ? "Local uncommitted changes, not checked in to index"
            : "Local changes checked in to index but not committed"
    }

    /// First entry of the file list, above the files.
    public static func fileListLabel(_ hash: String) -> String {
        switch hash {
        case unstaged: return "Unstaged changes"
        case staged: return "Staged changes"
        default: return "Commit"
        }
    }

    /// Rows for unstaged and staged changes, top first, the last one a child of HEAD.
    /// Empty when there are no changes. Paths after "--" in `args` limit the check.
    public static func load(repo: URL, args: [String]) -> [Commit] {
        let head = Git.run(["rev-parse", "--verify", "--quiet", "HEAD"], in: repo)
        guard head.status == 0 else { return [] }
        let paths = args.firstIndex(of: "--").map { Array(args[$0...]) } ?? []
        var parent = head.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        var rows: [Commit] = []
        // Exit code 1 means there are differences.
        if Git.run(["diff", "--cached", "--quiet"] + paths, in: repo).status == 1 {
            rows.append(row(staged, parent: parent))
            parent = staged
        }
        if Git.run(["diff", "--quiet"] + paths, in: repo).status == 1 {
            rows.insert(row(unstaged, parent: parent), at: 0)
        }
        return rows
    }

    private static func row(_ hash: String, parent: String) -> Commit {
        Commit(hash: hash, parents: [parent], author: "", date: Date(), subject: subject(hash), refs: [])
    }
}
