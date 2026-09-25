import Foundation

public enum LineKind: Sendable {
    case fileHeader, hunk, added, removed
}

/// A styled line. Locations and lengths are UTF-16 offsets into `CommitDetails.text`.
public struct DiffSpan: Equatable, Sendable {
    public let kind: LineKind
    public let location: Int
    public let length: Int
}

public struct FileEntry: Equatable, Sendable {
    public let path: String
    public let location: Int
}

public struct CommitDetails: Sendable {
    public var text: String
    public var files: [FileEntry]
    public var spans: [DiffSpan]
    public var truncated: Bool
}

/// Builds `CommitDetails` from `git show` output, one line at a time.
public struct DetailsParser {
    private enum State { case header, fileHeader, hunk }

    private let maxLines: Int
    private var lineCount = 0
    private var state = State.header
    private var hunkColumns = 1
    private var location = 0
    private var d = CommitDetails(text: "", files: [], spans: [], truncated: false)

    public init(maxLines: Int = 50_000) {
        self.maxLines = maxLines
    }

    /// Returns false once the line limit is hit; the line is then dropped.
    public mutating func add(_ line: String) -> Bool {
        guard lineCount < maxLines else {
            d.truncated = true
            return false
        }
        lineCount += 1

        if line.hasPrefix("diff --git ") || line.hasPrefix("diff --cc ") || line.hasPrefix("diff --combined ") {
            state = .fileHeader
            d.files.append(FileEntry(path: Self.path(fromDiffLine: line), location: location))
        } else if state != .header && line.hasPrefix("@@") {
            state = .hunk
            hunkColumns = line.prefix(while: { $0 == "@" }).count - 1
        }

        let length = line.utf16.count
        if let kind = kind(of: line) {
            d.spans.append(DiffSpan(kind: kind, location: location, length: length))
        }
        d.text += line
        d.text += "\n"
        location += length + 1
        return true
    }

    public func finish() -> CommitDetails {
        var out = d
        if out.truncated { out.text += "\n[gitview: diff cut at \(maxLines) lines]\n" }
        return out
    }

    private func kind(of line: String) -> LineKind? {
        switch state {
        case .header: return nil
        case .fileHeader: return .fileHeader
        case .hunk:
            if line.hasPrefix("@@") { return .hunk }
            let marks = line.prefix(hunkColumns)
            if marks.contains("+") { return .added }
            if marks.contains("-") { return .removed }
            return nil
        }
    }

    static func path(fromDiffLine line: String) -> String {
        for prefix in ["diff --cc ", "diff --combined "] {
            if let rest = line.stripping(prefix) { return rest }
        }
        let rest = Array(line.dropFirst("diff --git ".count))
        // "a/X b/X": both halves equal, which also works when X contains " b/".
        let n = rest.count
        if n > 5, (n - 5) % 2 == 0 {
            let half = (n - 5) / 2
            let a = rest[2..<(2 + half)]
            let sep = rest[(2 + half)..<(5 + half)]
            let b = rest[(5 + half)...]
            if String(sep) == " b/" && a == b { return String(a) }
        }
        let s = String(rest)
        if let r = s.range(of: " b/", options: .backwards) { return String(s[r.upperBound...]) }
        return s
    }
}
