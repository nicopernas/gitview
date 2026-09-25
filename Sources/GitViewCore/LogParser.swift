import Foundation

public enum LogParser {
    /// Must match the field order in `parse`. Fields are NUL separated.
    public static let format = "%H%x00%P%x00%an%x00%at%x00%D%x00%s"

    public static func parse(_ line: String) -> Commit? {
        let f = line.split(separator: "\0", maxSplits: 5, omittingEmptySubsequences: false)
        guard f.count == 6, let time = TimeInterval(f[3]) else { return nil }
        return Commit(
            hash: String(f[0]),
            parents: f[1].split(separator: " ").map(String.init),
            author: String(f[2]),
            date: Date(timeIntervalSince1970: time),
            subject: String(f[5]),
            refs: f[4].isEmpty ? [] : parseRefs(String(f[4])))
    }

    /// Parses `%D` output produced with `--decorate=full`.
    static func parseRefs(_ s: String) -> [Ref] {
        var refs: [Ref] = []
        for part in s.components(separatedBy: ", ") {
            if part == "HEAD" {
                refs.append(Ref(name: "HEAD", kind: .other, isHead: true))
            } else if part.hasPrefix("HEAD -> ") {
                if let r = ref(String(part.dropFirst(8)), isHead: true) { refs.append(r) }
            } else if part.hasPrefix("tag: ") {
                if let r = ref(String(part.dropFirst(5)), isHead: false) { refs.append(r) }
            } else if let r = ref(part, isHead: false) {
                refs.append(r)
            }
        }
        return refs
    }

    private static func ref(_ full: String, isHead: Bool) -> Ref? {
        if let name = full.stripping("refs/heads/") {
            return Ref(name: name, kind: .branch, isHead: isHead)
        }
        if let name = full.stripping("refs/remotes/") {
            if name.hasSuffix("/HEAD") { return nil }
            return Ref(name: name, kind: .remote, isHead: isHead)
        }
        if let name = full.stripping("refs/tags/") {
            return Ref(name: name, kind: .tag, isHead: isHead)
        }
        return Ref(name: full, kind: .other, isHead: isHead)
    }
}

extension String {
    func stripping(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
