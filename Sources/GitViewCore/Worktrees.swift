import Foundation

public struct Worktree: Equatable, Sendable {
    public let path: String
    /// Short branch name; nil when HEAD is detached.
    public let branch: String?
    public let head: String
    /// The worktree's folder is gone.
    public let prunable: Bool

    /// "name (branch)" or "name (detached abc1234)".
    public var title: String {
        "\((path as NSString).lastPathComponent) (\(branch ?? "detached " + head.prefix(7)))"
    }
}

public enum Worktrees {
    /// Parses `git worktree list --porcelain`. Bare entries are skipped.
    public static func parse(_ text: String) -> [Worktree] {
        var list: [Worktree] = []
        var path: String?
        var head = ""
        var branch: String?
        var bare = false
        var prunable = false
        func flush() {
            if let path, !bare { list.append(Worktree(path: path, branch: branch, head: head, prunable: prunable)) }
            path = nil
            head = ""
            branch = nil
            bare = false
            prunable = false
        }
        for line in text.components(separatedBy: "\n") {
            if let p = line.stripping("worktree ") {
                flush()
                path = p
            } else if let h = line.stripping("HEAD ") {
                head = h
            } else if let b = line.stripping("branch ") {
                branch = b.stripping("refs/heads/") ?? b
            } else if line == "bare" {
                bare = true
            } else if line == "prunable" || line.hasPrefix("prunable ") {
                prunable = true
            }
        }
        flush()
        return list
    }

    public static func load(repo: URL) -> [Worktree] {
        let r = Git.run(["worktree", "list", "--porcelain"], in: repo)
        return r.status == 0 ? parse(r.stdout) : []
    }

    public static func find(_ dir: URL, in list: [Worktree]) -> Int? {
        let target = dir.resolvingSymlinksInPath().path
        return list.firstIndex { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path == target }
    }

    /// Where to go when `dir` was removed: the first worktree still on disk. Nil if `dir` exists.
    public static func fallback(for dir: URL, in list: [Worktree]) -> Worktree? {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: dir.path) else { return nil }
        return list.first { fm.fileExists(atPath: $0.path) }
    }

    /// The next (step 1) or previous (step -1) worktree after `dir`, wrapping around and
    /// skipping prunable ones. Nil when there is no other.
    public static func next(from dir: URL, in list: [Worktree], step: Int) -> Worktree? {
        guard var i = find(dir, in: list) else { return nil }
        for _ in 1..<list.count {
            i = (i + step + list.count) % list.count
            if !list[i].prunable { return list[i] }
        }
        return nil
    }
}
