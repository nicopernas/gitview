import AppKit
import GitViewCore

private let tabKey: UInt16 = 48

/// Tab / Shift+Tab move to the next / previous pane. Returns true if handled.
private func handleTab(_ event: NSEvent, from sender: NSResponder) -> Bool {
    guard event.keyCode == tabKey else { return false }
    let back = event.modifierFlags.contains(.shift)
    let action = back ? #selector(MainWindowController.gvPreviousPane(_:)) : #selector(MainWindowController.gvNextPane(_:))
    NSApp.sendAction(action, to: nil, from: sender)
    return true
}

/// "/" acts like Cmd+F (Find). Returns true if handled.
private func handleSlash(_ event: NSEvent, from sender: NSResponder) -> Bool {
    guard event.characters == "/", event.modifierFlags.isDisjoint(with: [.command, .control, .option]) else { return false }
    NSApp.sendAction(#selector(MainWindowController.gvFind(_:)), to: nil, from: sender)
    return true
}

/// Table that sends Space to the diff, Tab to the next pane, and Cmd+C to `onCopy`.
final class KeyTableView: NSTableView {
    var onSpace: ((_ up: Bool) -> Void)?
    var onCopy: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if handleTab(event, from: self) || handleSlash(event, from: self) { return }
        if event.charactersIgnoringModifiers == " " {
            onSpace?(event.modifierFlags.contains(.shift))
            return
        }
        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) {
        onCopy?()
    }
}

final class DiffTextView: NSTextView {
    /// Character ranges of each file's header lines; drawn on a full-width band.
    var headerBlocks: [NSRange] = [] {
        didSet { needsDisplay = true }
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard !headerBlocks.isEmpty, let lm = layoutManager, let tc = textContainer else { return }
        let origin = textContainerOrigin
        let visible = lm.glyphRange(forBoundingRect: rect.offsetBy(dx: -origin.x, dy: -origin.y), in: tc)
        let chars = lm.characterRange(forGlyphRange: visible, actualGlyphRange: nil)
        for block in headerBlocks where NSIntersectionRange(block, chars).length > 0 {
            var used = NSRect.null
            let glyphs = lm.glyphRange(forCharacterRange: block, actualCharacterRange: nil)
            lm.enumerateLineFragments(forGlyphRange: glyphs) { _, lineUsed, _, _, _ in used = used.union(lineUsed) }
            guard !used.isNull else { continue }
            let band = NSRect(x: bounds.minX, y: used.minY + origin.y - 3, width: bounds.width, height: used.height + 6)
            Palette.headerBand.setFill()
            band.fill()
            NSColor.separatorColor.setFill()
            NSRect(x: band.minX, y: band.minY, width: band.width, height: 1).fill()
        }
    }

    override func keyDown(with event: NSEvent) {
        if handleTab(event, from: self) || handleSlash(event, from: self) { return }
        if event.charactersIgnoringModifiers == " " {
            if event.modifierFlags.contains(.shift) { scrollPageUp(nil) } else { scrollPageDown(nil) }
            return
        }
        super.keyDown(with: event)
    }

    func finderAction(_ action: NSTextFinder.Action) {
        let item = NSMenuItem()
        item.tag = action.rawValue
        performTextFinderAction(item)
    }
}

/// A plain text cell for view-based tables.
func textCell(_ table: NSTableView, _ id: NSUserInterfaceItemIdentifier, _ text: String, font: NSFont,
              truncate: NSLineBreakMode = .byTruncatingTail) -> NSTableCellView {
    if let cell = table.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
        cell.textField?.stringValue = text
        cell.textField?.font = font
        return cell
    }
    let cell = NSTableCellView()
    cell.identifier = id
    let field = NSTextField(labelWithString: text)
    field.font = font
    field.lineBreakMode = truncate
    field.translatesAutoresizingMaskIntoConstraints = false
    cell.addSubview(field)
    cell.textField = field
    NSLayoutConstraint.activate([
        field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
        field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
        field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
    ])
    return cell
}

/// Window that reports first responder changes.
final class MainWindow: NSWindow {
    var onFirstResponderChange: (() -> Void)?

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        let ok = super.makeFirstResponder(responder)
        onFirstResponderChange?()
        return ok
    }
}

/// Wraps a pane and draws a thin border around it while it has focus.
final class PaneView: NSView {
    enum Focus { case none, active, inactive }

    var focus = Focus.none {
        didSet { if focus != oldValue { updateBorder() } }
    }

    init(_ content: NSView) {
        super.init(frame: .zero)
        wantsLayer = true
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBorder()
    }

    private func updateBorder() {
        guard let layer else { return }
        // A layer border is drawn above sublayers, so it shows over the scroll view.
        layer.borderWidth = focus == .none ? 0 : 1
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let color: NSColor = focus == .active ? .controlAccentColor : .tertiaryLabelColor
            layer.borderColor = color.cgColor
        }
    }
}

/// Pane background: softer than the system's pure white / near black.
enum Palette {
    private static func rgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? rgb(dark) : rgb(light)
        }
    }

    /// Soft gray: #F3F3F3 in light mode, #2A2A2A in dark mode.
    static let background = dynamic(light: 0xF3F3F3, dark: 0x2A2A2A)

    /// Band behind each file's header in the diff, a step away from `background`.
    static let headerBand = dynamic(light: 0xE3E3E3, dark: 0x383838)

    // Commit message colors from nvim's onedark theme: "light" and "darker" styles.
    private static let red = dynamic(light: 0xE45649, dark: 0xE55561)
    private static let blue = dynamic(light: 0x4078F2, dark: 0x4FA6ED)
    private static let grey = dynamic(light: 0x818387, dark: 0x7A818E)

    /// Color for a part of a commit message; nil keeps the normal text color.
    static func color(_ kind: MessageKind) -> NSColor? {
        switch kind {
        case .subject, .type, .scope, .bang: nil
        case .trailerToken, .breakingChange: red
        case .punctuation: grey
        case .subjectPrefix: blue
        }
    }

    /// The prefix ("solver", "feat(ui)!") is bold; the subject line only in the diff.
    static func isBold(_ kind: MessageKind, inList: Bool) -> Bool {
        switch kind {
        case .type, .scope, .bang: true
        case .subject: !inList
        default: false
        }
    }
}

