import Testing
@testable import GitViewCore

private func line(_ from: Int, _ to: Int, _ color: Int) -> GraphLine {
    GraphLine(from: from, to: to, color: color)
}

@Suite struct GraphLayoutTests {
    @Test func linearHistoryStaysInOneColumn() {
        var g = GraphLayout()
        let a = g.add(hash: "A", parents: ["B"])
        let b = g.add(hash: "B", parents: ["C"])
        let c = g.add(hash: "C", parents: [])

        #expect(a.column == 0 && b.column == 0 && c.column == 0)
        #expect(a.top.isEmpty)
        #expect(a.bottom == [line(0, 0, 0)])
        #expect(b.top == [line(0, 0, 0)])
        #expect(b.bottom == [line(0, 0, 0)])
        #expect(c.top == [line(0, 0, 0)])
        #expect(c.bottom.isEmpty)
    }

    @Test func branchAndMerge() {
        var g = GraphLayout()
        let m = g.add(hash: "M", parents: ["A", "B"])
        let a = g.add(hash: "A", parents: ["X"])
        let b = g.add(hash: "B", parents: ["X"])
        let x = g.add(hash: "X", parents: [])

        #expect(m.column == 0 && m.color == 0)
        #expect(Set(m.bottom) == [line(0, 0, 0), line(0, 1, 1)])

        #expect(a.column == 0)
        #expect(Set(a.top) == [line(0, 0, 0), line(1, 1, 1)])
        #expect(Set(a.bottom) == [line(0, 0, 0), line(1, 1, 1)])

        #expect(b.column == 1 && b.color == 1)
        #expect(Set(b.top) == [line(0, 0, 0), line(1, 1, 1)])
        #expect(Set(b.bottom) == [line(0, 0, 0), line(1, 1, 1)])

        #expect(x.column == 0)
        #expect(Set(x.top) == [line(0, 0, 0), line(1, 0, 1)])
        #expect(x.bottom.isEmpty)
    }

    @Test func secondTipGetsNewColumn() {
        var g = GraphLayout()
        _ = g.add(hash: "T1", parents: ["X"])
        let t2 = g.add(hash: "T2", parents: ["X"])
        let x = g.add(hash: "X", parents: [])

        #expect(t2.column == 1 && t2.color == 1)
        #expect(t2.top == [line(0, 0, 0)])
        #expect(Set(t2.bottom) == [line(0, 0, 0), line(1, 1, 1)])
        #expect(Set(x.top) == [line(0, 0, 0), line(1, 0, 1)])
    }

    @Test func freedColumnIsReused() {
        var g = GraphLayout()
        _ = g.add(hash: "A", parents: ["P"])
        _ = g.add(hash: "B", parents: ["Q"])
        let p = g.add(hash: "P", parents: [])
        let c = g.add(hash: "C", parents: ["R"])

        #expect(Set(p.top) == [line(0, 0, 0), line(1, 1, 1)])
        #expect(p.bottom == [line(1, 1, 1)])
        #expect(c.column == 0)
        #expect(c.top == [line(1, 1, 1)])
        #expect(Set(c.bottom) == [line(0, 0, 2), line(1, 1, 1)])
    }

    @Test func mergeIntoParentAlreadyWaitingJoinsThatLane() {
        var g = GraphLayout()
        _ = g.add(hash: "F", parents: ["B"])
        let m = g.add(hash: "M", parents: ["A", "B"])

        #expect(m.column == 1)
        #expect(Set(m.bottom) == [line(0, 0, 0), line(1, 1, 1), line(1, 0, 0)])
    }

    @Test func octopusMergeFansOut() {
        var g = GraphLayout()
        let m = g.add(hash: "M", parents: ["A", "B", "C"])
        #expect(Set(m.bottom) == [line(0, 0, 0), line(0, 1, 1), line(0, 2, 2)])
        #expect(m.width == 3)
    }

    @Test func colorsWrapAround() {
        var g = GraphLayout(colors: 2)
        _ = g.add(hash: "M", parents: ["A", "B", "C"])
        let c = g.add(hash: "C", parents: [])
        #expect(c.color == 0)
    }

    @Test func trailingEmptyColumnsAreTrimmed() {
        var g = GraphLayout()
        _ = g.add(hash: "M", parents: ["A", "B"])
        _ = g.add(hash: "B", parents: [])
        let a = g.add(hash: "A", parents: [])
        #expect(a.width == 1)
    }
}
