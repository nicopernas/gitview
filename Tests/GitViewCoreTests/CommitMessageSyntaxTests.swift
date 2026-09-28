import Foundation
import Testing
@testable import GitViewCore

/// (kind, text) pairs, to keep expectations readable.
private func parts(_ s: String, _ spans: [MessageSpan]) -> [(MessageKind, String)] {
    spans.map { ($0.kind, (s as NSString).substring(with: NSRange(location: $0.location, length: $0.length))) }
}

private func expectParts(_ got: [(MessageKind, String)], _ want: [(MessageKind, String)]) {
    #expect(got.map(\.0) == want.map(\.0))
    #expect(got.map(\.1) == want.map(\.1))
}

@Suite struct CommitMessageSyntaxTests {
    @Test func plainSubjectIsOneSpan() {
        let s = "Fix the parser"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [(.subject, s)])
    }

    @Test func conventionalPrefix() {
        let s = "feat(ui)!: add button"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [
            (.subject, s), (.type, "feat"), (.punctuation, "("), (.scope, "ui"), (.punctuation, ")"),
            (.bang, "!"), (.punctuation, ":"),
        ])
    }

    @Test func areaPrefixLikeRelayerCommits() {
        let s = "solver: a route per chain"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [(.subject, s), (.type, "solver"), (.punctuation, ":")])
    }

    @Test func prefixNeedsTextAfterTheColon() {
        let s = "feat:"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [(.subject, s)])
    }

    @Test func typeCannotContainSpaces() {
        let s = "Merge pull request #1: stuff"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [(.subject, s)])
    }

    @Test func emptyScopeIsNotAPrefix() {
        let s = "feat(): x"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [(.subject, s)])
    }

    @Test func fixupAndAmendPrefixes() {
        let s = "fixup! fix: typo"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [
            (.subject, s), (.subjectPrefix, "fixup!"), (.type, "fix"), (.punctuation, ":"),
        ])
        let a = "amend! Fix it"
        expectParts(parts(a, CommitMessageSyntax.subject(a)), [(.subject, a), (.subjectPrefix, "amend!")])
    }

    @Test func squashIsNotASubjectPrefix() {
        let s = "squash! Fix it"
        expectParts(parts(s, CommitMessageSyntax.subject(s)), [(.subject, s)])
    }

    @Test func trailerToken() {
        let s = "Co-Authored-By: Claude <noreply@anthropic.com>"
        expectParts(parts(s, CommitMessageSyntax.bodyLine(s)), [(.trailerToken, "Co-Authored-By: ")])
    }

    @Test func trailerNeedsSpaceAfterColon() {
        #expect(CommitMessageSyntax.bodyLine("Note:nospace").isEmpty)
        #expect(CommitMessageSyntax.bodyLine("Two words: no").isEmpty)
        #expect(CommitMessageSyntax.bodyLine("Just a sentence.").isEmpty)
    }

    @Test func breakingChange() {
        let s = "BREAKING CHANGE: drops the old API"
        expectParts(parts(s, CommitMessageSyntax.bodyLine(s)), [(.breakingChange, "BREAKING CHANGE: ")])
    }

    @Test func offsetsCountUTF16() {
        let s = "é😀: x"
        let spans = CommitMessageSyntax.subject(s)
        #expect(spans.first { $0.kind == .type } == MessageSpan(kind: .type, location: 0, length: 3))
    }
}
