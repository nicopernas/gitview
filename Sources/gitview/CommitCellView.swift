import AppKit
import GitViewCore

/// Draws the graph, ref labels and subject for one commit row.
final class CommitCellView: NSTableCellView {
    static let palette: [NSColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemPurple,
        .systemRed, .systemTeal, .systemPink, .systemBrown,
    ]
    private static let laneWidth: CGFloat = 14

    var commit: Commit?
    var graph: GraphRow?
    var font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    var boldFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
    var labelFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    var labelBoldFont = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)

    override var isFlipped: Bool { true }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let commit, let graph else { return }
        let h = bounds.height
        let mid = h / 2
        func x(_ col: Int) -> CGFloat { CGFloat(col) * Self.laneWidth + Self.laneWidth / 2 + 2 }

        for l in graph.top { stroke(from: NSPoint(x: x(l.from), y: 0), to: NSPoint(x: x(l.to), y: mid), l.color) }
        for l in graph.bottom { stroke(from: NSPoint(x: x(l.from), y: mid), to: NSPoint(x: x(l.to), y: h), l.color) }

        let r: CGFloat = 4
        let dot = NSBezierPath(ovalIn: NSRect(x: x(graph.column) - r, y: mid - r, width: 2 * r, height: 2 * r))
        let selected = backgroundStyle == .emphasized
        color(graph.color).setFill()
        dot.fill()
        if selected {
            NSColor.white.setStroke()
            dot.lineWidth = 1.5
            dot.stroke()
        }

        var textX = CGFloat(graph.width) * Self.laneWidth + 6
        for ref in commit.refs {
            textX += drawLabel(ref, at: textX, height: h, selected: selected) + 4
        }

        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let subject = NSMutableAttributedString(string: commit.subject, attributes: [
            .font: font,
            .foregroundColor: selected ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor,
            .paragraphStyle: style,
        ])
        // Same highlighting as nvim's gitcommit syntax; plain white on the selection.
        for s in CommitMessageSyntax.subject(commit.subject) {
            let range = NSRange(location: s.location, length: s.length)
            if s.kind == .subject { subject.addAttribute(.font, value: boldFont, range: range) }
            if !selected { subject.addAttribute(.foregroundColor, value: Palette.color(s.kind), range: range) }
        }
        let textH = ceil(boldFont.ascender - boldFont.descender)
        let rect = NSRect(x: textX, y: (h - textH) / 2, width: max(0, bounds.width - textX), height: textH)
        subject.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    private func color(_ i: Int) -> NSColor {
        Self.palette[i % Self.palette.count]
    }

    private func stroke(from a: NSPoint, to b: NSPoint, _ c: Int) {
        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.move(to: a)
        if a.x == b.x {
            path.line(to: b)
        } else {
            let midY = (a.y + b.y) / 2
            path.curve(to: b, controlPoint1: NSPoint(x: a.x, y: midY), controlPoint2: NSPoint(x: b.x, y: midY))
        }
        color(c).setStroke()
        path.stroke()
    }

    /// Returns the label width.
    private func drawLabel(_ ref: Ref, at x: CGFloat, height h: CGFloat, selected: Bool) -> CGFloat {
        let tint: NSColor
        switch ref.kind {
        case .branch: tint = .systemGreen
        case .remote: tint = .systemBlue
        case .tag: tint = .systemYellow
        case .other: tint = .systemGray
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: ref.isHead ? labelBoldFont : labelFont,
            .foregroundColor: selected ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor,
        ]
        let text = ref.name as NSString
        let size = text.size(withAttributes: attrs)
        let box = NSRect(x: x, y: 3, width: size.width + 10, height: h - 6)
        let path = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
        tint.withAlphaComponent(0.25).setFill()
        path.fill()
        tint.setStroke()
        path.lineWidth = 1
        path.stroke()
        text.draw(at: NSPoint(x: box.minX + 5, y: box.midY - size.height / 2), withAttributes: attrs)
        return box.width
    }
}
