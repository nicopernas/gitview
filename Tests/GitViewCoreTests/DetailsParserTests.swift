import Foundation
import Testing
@testable import GitViewCore

private func parse(_ lines: [String], maxLines: Int = 1000) -> CommitDetails {
    var p = DetailsParser(maxLines: maxLines)
    for l in lines { if !p.add(l) { break } }
    return p.finish()
}

private func text(_ d: CommitDetails, _ s: DiffSpan) -> String {
    (d.text as NSString).substring(with: NSRange(location: s.location, length: s.length))
}

@Suite struct DetailsParserTests {
    @Test func buildsTextAndFindsFiles() {
        let d = parse([
            "commit abc",
            "",
            "diff --git a/one.txt b/one.txt",
            "@@ -1 +1 @@",
            "diff --git a/two.txt b/two.txt",
        ])
        #expect(d.text == "commit abc\n\ndiff --git a/one.txt b/one.txt\n@@ -1 +1 @@\ndiff --git a/two.txt b/two.txt\n")
        #expect(d.files == [FileEntry(path: "one.txt", location: 12), FileEntry(path: "two.txt", location: 55)])
        #expect(!d.truncated)
    }

    @Test func classifiesDiffLines() {
        let d = parse([
            "    +not a diff line in the message",
            "diff --git a/f b/f",
            "index 111..222 100644",
            "--- a/f",
            "+++ b/f",
            "@@ -1,2 +1,2 @@",
            " same",
            "-old",
            "+new",
        ])
        #expect(d.spans.map(\.kind) == [.fileHeader, .fileHeader, .fileHeader, .fileHeader, .hunk, .removed, .added])
        #expect(d.spans.map { text(d, $0) } == [
            "diff --git a/f b/f", "index 111..222 100644", "--- a/f", "+++ b/f", "@@ -1,2 +1,2 @@", "-old", "+new",
        ])
    }

    @Test func classifiesCombinedDiffLines() {
        let d = parse([
            "diff --cc merged.c",
            "@@@ -1,2 -1,2 +1,3 @@@",
            "  same",
            " +from second",
            "- from first",
        ])
        #expect(d.files == [FileEntry(path: "merged.c", location: 0)])
        #expect(d.spans.map(\.kind) == [.fileHeader, .hunk, .added, .removed])
    }

    @Test func pathWithSpaces() {
        let d = parse(["diff --git a/my file b/x.txt b/my file b/x.txt"])
        #expect(d.files.map(\.path) == ["my file b/x.txt"])
    }

    @Test func renamedPathUsesNewName() {
        let d = parse(["diff --git a/old.txt b/new.txt"])
        #expect(d.files.map(\.path) == ["new.txt"])
    }

    @Test func locationsCountUTF16() {
        let d = parse(["é😀", "diff --git a/f b/f"])
        #expect(d.files == [FileEntry(path: "f", location: 4)])
    }

    @Test func groupsFileHeaderLinesIntoBlocks() {
        let d = parse([
            "commit abc",
            "diff --git a/one b/one",
            "index 1..2 100644",
            "--- a/one",
            "+++ b/one",
            "@@ -1 +1 @@",
            "-x",
            "diff --git a/two b/two",
            "new file mode 100644",
            "@@ -0,0 +1 @@",
        ])
        #expect(d.fileHeaderBlocks.map { text(d, $0) } == [
            "diff --git a/one b/one\nindex 1..2 100644\n--- a/one\n+++ b/one",
            "diff --git a/two b/two\nnew file mode 100644",
        ])
    }

    @Test func truncatesAtMaxLines() {
        var p = DetailsParser(maxLines: 2)
        let accepted = [p.add("one"), p.add("two"), p.add("three")]
        #expect(accepted == [true, true, false])
        let d = p.finish()
        #expect(d.truncated)
        #expect(d.text.hasPrefix("one\ntwo\n"))
        #expect(!d.text.contains("three"))
        #expect(d.text.contains("cut at 2 lines"))
    }
}
