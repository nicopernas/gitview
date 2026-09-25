import Foundation

public enum Search {
    /// Index of the next (or previous) commit matching `query`, wrapping around.
    /// Matches subject or author (ignoring case), or a hash prefix.
    public static func find(_ query: String, in commits: [Commit], from start: Int, forward: Bool) -> Int? {
        let n = commits.count
        guard !query.isEmpty, n > 0 else { return nil }
        let hashPrefix = query.lowercased()
        let first = start < 0 ? (forward ? -1 : 0) : start
        for step in 1...n {
            let i = ((first + (forward ? step : -step)) % n + n) % n
            let c = commits[i]
            if c.hash.hasPrefix(hashPrefix)
                || c.subject.range(of: query, options: .caseInsensitive) != nil
                || c.author.range(of: query, options: .caseInsensitive) != nil {
                return i
            }
        }
        return nil
    }
}

extension Search {
    /// Files whose path contains `query`, ignoring case. Empty query keeps all.
    public static func files(_ files: [FileEntry], matching query: String) -> [FileEntry] {
        guard !query.isEmpty else { return files }
        return files.filter { $0.path.range(of: query, options: .caseInsensitive) != nil }
    }
}
