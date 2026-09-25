/// A line piece inside one half of a row, between two column positions.
public struct GraphLine: Hashable, Sendable {
    public let from: Int
    public let to: Int
    public let color: Int
}

public struct GraphRow: Equatable, Sendable {
    public let column: Int
    public let color: Int
    /// From the row's top edge to its middle.
    public let top: [GraphLine]
    /// From the row's middle to its bottom edge.
    public let bottom: [GraphLine]

    public var width: Int {
        var w = column
        for l in top { w = max(w, l.from, l.to) }
        for l in bottom { w = max(w, l.from, l.to) }
        return w + 1
    }
}

/// Assigns columns to commits fed in child-before-parent order.
public struct GraphLayout {
    private struct Lane {
        let hash: String
        let color: Int
    }

    private var lanes: [Lane?] = []
    private var colorCounter = 0
    private let colors: Int

    public init(colors: Int = 8) {
        self.colors = colors
    }

    public mutating func add(hash: String, parents: [String]) -> GraphRow {
        var column = -1
        var color = 0
        var top: [GraphLine] = []
        for i in lanes.indices {
            guard let lane = lanes[i] else { continue }
            if lane.hash == hash {
                if column < 0 {
                    column = i
                    color = lane.color
                }
                top.append(GraphLine(from: i, to: column, color: lane.color))
                lanes[i] = nil
            } else {
                top.append(GraphLine(from: i, to: i, color: lane.color))
            }
        }

        var bottom: [GraphLine] = []
        for i in lanes.indices {
            if let lane = lanes[i] { bottom.append(GraphLine(from: i, to: i, color: lane.color)) }
        }

        if column < 0 {
            column = freeSlot()
            color = newColor()
        }
        if let first = parents.first {
            lanes[column] = Lane(hash: first, color: color)
            bottom.append(GraphLine(from: column, to: column, color: color))
        }
        for p in parents.dropFirst() {
            if let j = lanes.firstIndex(where: { $0?.hash == p }), let lane = lanes[j] {
                bottom.append(GraphLine(from: column, to: j, color: lane.color))
            } else {
                let j = freeSlot()
                let c = newColor()
                lanes[j] = Lane(hash: p, color: c)
                bottom.append(GraphLine(from: column, to: j, color: c))
            }
        }

        while let last = lanes.last, last == nil { lanes.removeLast() }
        return GraphRow(column: column, color: color, top: top, bottom: bottom)
    }

    private mutating func freeSlot() -> Int {
        if let i = lanes.firstIndex(where: { $0 == nil }) { return i }
        lanes.append(nil)
        return lanes.count - 1
    }

    private mutating func newColor() -> Int {
        defer { colorCounter += 1 }
        return colorCounter % colors
    }
}
