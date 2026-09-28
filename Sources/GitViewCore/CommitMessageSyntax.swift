import Foundation

public enum MessageKind: Sendable {
    case subject, type, scope, punctuation, bang, subjectPrefix, trailerToken, breakingChange
}

/// A highlighted part of a commit message. Location and length are UTF-16 offsets.
public struct MessageSpan: Equatable, Sendable {
    public let kind: MessageKind
    public let location: Int
    public let length: Int
}

/// Commit message highlighting, following nvim's tree-sitter-gitcommit grammar
/// (github.com/gbprod/tree-sitter-gitcommit, grammar.js and src/scanner.c).
public enum CommitMessageSyntax {
    /// Spans for a subject line: the whole line, plus "fixup!"/"amend!" and a
    /// conventional prefix like "feat(ui)!:" when present.
    public static func subject(_ s: String) -> [MessageSpan] {
        let c = Array(s.unicodeScalars)
        var offsets = [0]
        for u in c { offsets.append(offsets[offsets.count - 1] + u.utf16.count) }
        func span(_ kind: MessageKind, _ from: Int, _ to: Int) -> MessageSpan {
            MessageSpan(kind: kind, location: offsets[from], length: offsets[to] - offsets[from])
        }

        var spans = [span(.subject, 0, c.count)]
        var start = 0
        for p in ["fixup!", "amend!"] where s.hasPrefix(p) {
            let n = p.unicodeScalars.count
            var j = n
            while j < c.count, ["\u{20}", "\u{0B}", "\u{0C}"].contains(c[j]) { j += 1 }
            if j > n {
                spans.append(span(.subjectPrefix, 0, n))
                start = j
            }
        }
        if let parts = prefix(c, from: start) {
            spans += parts.map { span($0.kind, $0.from, $0.to) }
        }
        return spans
    }

    /// Spans for a body line: a trailer name ("Signed-off-by: ") or "BREAKING CHANGE: ".
    public static func bodyLine(_ s: String) -> [MessageSpan] {
        for (pattern, kind) in [(#"^BREAKING[- ]CHANGE *[:：] "#, MessageKind.breakingChange),
                                (#"^[a-zA-Z-]+ *[:：] "#, .trailerToken)] {
            if let r = s.range(of: pattern, options: .regularExpression) {
                return [MessageSpan(kind: kind, location: 0, length: s[r].utf16.count)]
            }
        }
        return []
    }

    /// The conventional prefix "type(scope)!:" at `i`, as in the grammar's scanner.
    private static func prefix(_ c: [Unicode.Scalar], from i: Int) -> [(kind: MessageKind, from: Int, to: Int)]? {
        func isControl(_ u: Unicode.Scalar) -> Bool { CharacterSet.controlCharacters.contains(u) }
        func isBreak(_ u: Unicode.Scalar) -> Bool { isControl(u) || CharacterSet.whitespacesAndNewlines.contains(u) }

        var j = i
        guard j < c.count, !isBreak(c[j]), c[j] != ":", c[j] != "!" else { return nil }
        j += 1
        while j < c.count, !isBreak(c[j]), !":!()".unicodeScalars.contains(c[j]) { j += 1 }
        var parts: [(kind: MessageKind, from: Int, to: Int)] = [(.type, i, j)]

        if j < c.count, c[j] == "(" {
            let open = j
            j += 1
            if j < c.count, c[j] == ")" { return nil }
            while j < c.count, !isControl(c[j]), c[j] != "(", c[j] != ")" { j += 1 }
            guard j < c.count, c[j] == ")" else { return nil }
            parts += [(.punctuation, open, open + 1), (.scope, open + 1, j), (.punctuation, j, j + 1)]
            j += 1
        }
        if j < c.count, c[j] == "!" {
            parts.append((.bang, j, j + 1))
            j += 1
        }
        guard j < c.count, c[j] == ":" || c[j] == "：" else { return nil }
        parts.append((.punctuation, j, j + 1))
        // The grammar needs at least one character after the colon.
        return j + 1 < c.count ? parts : nil
    }
}
