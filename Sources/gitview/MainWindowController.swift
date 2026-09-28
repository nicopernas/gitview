import AppKit
import GitViewCore

private extension NSUserInterfaceItemIdentifier {
    static let subject = Self("subject")
    static let author = Self("author")
    static let date = Self("date")
    static let file = Self("file")
    static let search = Self("search")
}

final class MainWindowController: NSWindowController, NSWindowDelegate, NSTableViewDataSource,
    NSTableViewDelegate, NSToolbarDelegate, NSSearchFieldDelegate {
    private let repo: URL
    /// Where git runs: the launch directory, so relative paths in `args` work.
    private let workDir: URL
    private let args: [String]

    private var commits: [Commit] = []
    private var rows: [GraphRow] = []
    private var details: CommitDetails?
    /// Files of the current commit that match the file filter.
    private var visibleFiles: [FileEntry] = []

    private var loader: LogLoader?
    private var loadGen = 0
    private var loadStart = Date()
    private var pendingHash: String?
    private var detailsCancel: GitCancel?
    private var detailsGen = 0

    private let commitTable = KeyTableView()
    private let fileTable = KeyTableView()
    private let fileFilter = NSSearchField()
    private let diffView = DiffTextView(usingTextLayoutManager: false)
    private let diffScroll = NSScrollView()
    private let searchField = NSSearchField()
    private let statusLabel = NSTextField(labelWithString: "")
    /// Full hash of the selected commit, above the file list.
    private let hashLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton()
    private var panes: [PaneView] = []

    private var font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private var boldFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
    private var labelFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    private var labelBoldFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .bold)
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    init(repo: URL, workDir: URL, args: [String]) {
        self.repo = repo
        self.workDir = workDir
        self.args = args
        let window = MainWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 900),
                                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                backing: .buffered, defer: false)
        super.init(window: window)
        window.delegate = self
        window.onFirstResponderChange = { [weak self] in self?.updatePaneFocus() }
        window.title = ([repo.lastPathComponent] + args).joined(separator: " ")
        buildUI(window)
        applyFont(Self.resolve(FontPreference.load()))
        NSFontManager.shared.target = self
        if !window.setFrameUsingName("gitview.window") { window.center() }
        window.setFrameAutosaveName("gitview.window")
        startLoading(select: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Layout

    private func buildUI(_ window: NSWindow) {
        setUpCommitTable()
        setUpFileTable()
        setUpDiffView()

        let toolbar = NSToolbar(identifier: "gitview.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        panes = [PaneView(scroll(commitTable)), PaneView(filePane()), PaneView(diffScroll)]
        let left = splitView(vertical: false, name: "gitview.split.left",
                             [panes[0], panes[1]], defaults: [-220], holding: 1)
        let main = splitView(vertical: true, name: "gitview.split.main",
                             [left, panes[2]], defaults: [620], holding: 0)

        statusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        let content = NSView()
        for v in [main, statusLabel] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(v)
        }
        NSLayoutConstraint.activate([
            main.topAnchor.constraint(equalTo: content.topAnchor),
            main.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            main.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: main.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -4),
        ])
        window.contentView = content

        // Tab is handled by gvNextPane / gvPreviousPane; search fields are reached with Cmd+F or a click.
        window.initialFirstResponder = commitTable

        window.layoutIfNeeded()
        main.restoreOrSetDefaults()
        left.restoreOrSetDefaults()
        commitTable.sizeToFit()
    }

    private func setUpCommitTable() {
        let t = commitTable
        let columns: [(NSUserInterfaceItemIdentifier, String, CGFloat)] = [
            (.subject, "Subject", 300), (.author, "Author", 130), (.date, "Date", 130),
        ]
        for (id, title, width) in columns {
            let col = NSTableColumn(identifier: id)
            col.title = title
            col.width = width
            col.minWidth = 40
            t.addTableColumn(col)
        }
        t.style = .plain
        t.backgroundColor = Palette.background
        t.intercellSpacing = NSSize(width: 6, height: 0)
        t.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        t.allowsMultipleSelection = false
        t.allowsEmptySelection = true
        t.autosaveName = "gitview.commits"
        t.autosaveTableColumns = true
        t.dataSource = self
        t.delegate = self
        t.onSpace = { [weak self] up in self?.pageDiff(up: up) }
        t.onCopy = { [weak self] in
            guard let self, let c = self.selectedCommit else { return }
            self.copyToPasteboard(c.hash)
        }
    }

    private func setUpFileTable() {
        let t = fileTable
        let col = NSTableColumn(identifier: .file)
        col.resizingMask = .autoresizingMask
        t.addTableColumn(col)
        t.headerView = nil
        t.style = .plain
        t.backgroundColor = Palette.background
        t.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        t.dataSource = self
        t.delegate = self
        t.onSpace = { [weak self] up in self?.pageDiff(up: up) }
        t.onCopy = { [weak self] in
            guard let self, let f = self.fileEntry(at: self.fileTable.selectedRow) else { return }
            self.copyToPasteboard(f.path)
        }

        fileFilter.placeholderString = "Filter files"
        fileFilter.controlSize = .small
        fileFilter.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        fileFilter.sendsSearchStringImmediately = true
        fileFilter.delegate = self
    }

    private func filePane() -> NSView {
        hashLabel.textColor = .secondaryLabelColor
        hashLabel.isSelectable = true
        hashLabel.lineBreakMode = .byTruncatingTail
        hashLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy hash")
        copyButton.isBordered = false
        copyButton.toolTip = "Copy hash"
        copyButton.refusesFirstResponder = true
        copyButton.target = self
        copyButton.action = #selector(copyHash(_:))

        let pane = NSView()
        let list = scroll(fileTable)
        for v in [hashLabel, copyButton, fileFilter, list] as [NSView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            pane.addSubview(v)
        }
        NSLayoutConstraint.activate([
            hashLabel.topAnchor.constraint(equalTo: pane.topAnchor, constant: 6),
            hashLabel.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 8),
            hashLabel.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -6),
            copyButton.centerYAnchor.constraint(equalTo: hashLabel.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -8),
            fileFilter.topAnchor.constraint(equalTo: hashLabel.bottomAnchor, constant: 6),
            fileFilter.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 6),
            fileFilter.trailingAnchor.constraint(equalTo: pane.trailingAnchor, constant: -6),
            list.topAnchor.constraint(equalTo: fileFilter.bottomAnchor, constant: 4),
            list.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            list.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            list.bottomAnchor.constraint(equalTo: pane.bottomAnchor),
        ])
        return pane
    }

    private func setUpDiffView() {
        let tv = diffView
        tv.isEditable = false
        tv.isSelectable = true
        tv.isRichText = false
        tv.backgroundColor = Palette.background
        tv.textContainerInset = NSSize(width: 6, height: 6)
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.layoutManager?.allowsNonContiguousLayout = true
        // Wrap long lines at the view's width.
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        tv.isHorizontallyResizable = false
        tv.isVerticallyResizable = true
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true

        diffScroll.hasVerticalScroller = true
        diffScroll.backgroundColor = Palette.background
        diffScroll.documentView = tv
    }

    private func scroll(_ table: NSTableView) -> NSScrollView {
        let s = NSScrollView()
        s.hasVerticalScroller = true
        s.backgroundColor = Palette.background
        s.documentView = table
        return s
    }

    /// `holding` is the pane that keeps its size when the window resizes.
    private func splitView(vertical: Bool, name: String, _ views: [NSView], defaults: [CGFloat],
                           holding: Int) -> SavedSplitView {
        let s = SavedSplitView()
        s.isVertical = vertical
        s.dividerStyle = .thin
        for v in views { s.addArrangedSubview(v) }
        s.setHoldingPriority(.defaultLow + 1, forSubviewAt: holding)
        s.defaultPositions = defaults
        s.enableAutosave(name)
        return s
    }

    // MARK: - Font

    private static func resolve(_ p: FontPreference) -> NSFont {
        NSFont(name: p.name, size: p.size) ?? .monospacedSystemFont(ofSize: p.size, weight: .regular)
    }

    private func applyFont(_ f: NSFont) {
        let fm = NSFontManager.shared
        font = f
        boldFont = fm.convert(f, toHaveTrait: .boldFontMask)
        labelFont = fm.convert(f, toSize: max(f.pointSize - 1, 8))
        labelBoldFont = fm.convert(labelFont, toHaveTrait: .boldFontMask)
        fm.setSelectedFont(f, isMultiple: false)

        let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: f))
        commitTable.rowHeight = lineHeight + 8
        fileTable.rowHeight = lineHeight + 4
        if let date = commitTable.tableColumn(withIdentifier: .date) {
            date.minWidth = ceil(("0000-00-00 00:00" as NSString).size(withAttributes: [.font: f]).width) + 12
            date.width = max(date.width, date.minWidth)
        }
        diffView.font = f
        hashLabel.font = f
        commitTable.reloadData()
        fileTable.reloadData()
        if let details { render(details) }
    }

    /// Sent by the font panel and the Bigger / Smaller menu items.
    @objc func changeFont(_ sender: Any?) {
        guard let fm = sender as? NSFontManager else { return }
        setFont(fm.convert(font))
    }

    @objc func gvResetFont(_ sender: Any?) {
        setFont(Self.resolve(.standard))
    }

    private func setFont(_ f: NSFont) {
        FontPreference(name: f.fontName, size: Double(f.pointSize)).save()
        Log.info("font: \(f.fontName) \(f.pointSize)")
        applyFont(f)
    }

    // MARK: - Toolbar

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, NSToolbarItem.Identifier(NSUserInterfaceItemIdentifier.search.rawValue)]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard id.rawValue == NSUserInterfaceItemIdentifier.search.rawValue else { return nil }
        let item = NSSearchToolbarItem(itemIdentifier: id)
        item.searchField = searchField
        item.preferredWidthForSearchField = 280
        searchField.placeholderString = "Find subject, author or hash"
        searchField.sendsWholeSearchString = true
        searchField.delegate = self
        return item
    }

    // MARK: - Search fields

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if control === searchField {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                findCommit(forward: !(NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false))
                return true
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) || isTab(selector) {
                window?.makeFirstResponder(commitTable)
                return true
            }
        } else if control === fileFilter {
            if isTab(selector) {
                window?.makeFirstResponder(fileTable)
                return true
            }
            if selector == #selector(NSResponder.insertNewline(_:)) || selector == #selector(NSResponder.moveDown(_:)) {
                window?.makeFirstResponder(fileTable)
                if let i = firstFileRow { fileTable.selectRowIndexes([i], byExtendingSelection: false) }
                return true
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                fileFilter.stringValue = ""
                applyFileFilter()
                window?.makeFirstResponder(fileTable)
                return true
            }
        }
        return false
    }

    private func isTab(_ selector: Selector) -> Bool {
        selector == #selector(NSResponder.insertTab(_:)) || selector == #selector(NSResponder.insertBacktab(_:))
    }

    func controlTextDidChange(_ obj: Notification) {
        if (obj.object as AnyObject?) === fileFilter { applyFileFilter() }
    }

    private func applyFileFilter() {
        visibleFiles = Search.files(details?.files ?? [], matching: fileFilter.stringValue)
        fileTable.reloadData()
    }

    /// The "Commit" row is hidden while filtering.
    private var showsCommitRow: Bool { fileFilter.stringValue.isEmpty }

    private func fileEntry(at row: Int) -> FileEntry? {
        let i = showsCommitRow ? row - 1 : row
        return i >= 0 && i < visibleFiles.count ? visibleFiles[i] : nil
    }

    private var firstFileRow: Int? {
        visibleFiles.isEmpty ? nil : (showsCommitRow ? 1 : 0)
    }

    // MARK: - Menu actions

    @objc func gvFind(_ sender: Any?) {
        Log.info("find: responder=\(responderName) diff=\(diffHasFocus) files=\(fileListHasFocus)")
        if diffHasFocus {
            diffView.finderAction(.showFindInterface)
        } else if fileListHasFocus {
            window?.makeFirstResponder(fileFilter)
        } else {
            window?.makeFirstResponder(searchField)
        }
    }

    @objc func gvFindNext(_ sender: Any?) {
        if diffHasFocus { diffView.finderAction(.nextMatch) } else { findCommit(forward: true) }
    }

    @objc func gvFindPrevious(_ sender: Any?) {
        if diffHasFocus { diffView.finderAction(.previousMatch) } else { findCommit(forward: false) }
    }

    @objc func gvReload(_ sender: Any?) {
        startLoading(select: selectedCommit?.hash)
    }

    @objc func gvNextPane(_ sender: Any?) { movePane(by: 1) }
    @objc func gvPreviousPane(_ sender: Any?) { movePane(by: -1) }

    /// Cycles focus through commits, diff and files.
    private func movePane(by step: Int) {
        let order = [0, 2, 1] // indexes into `panes` and `targets`
        let targets: [NSView] = [commitTable, fileTable, diffView]
        let owner = focusOwner as? NSView
        let pane = panes.firstIndex { owner?.isDescendant(of: $0) ?? false } ?? 0
        let next = order[((order.firstIndex(of: pane) ?? 0) + step + order.count) % order.count]
        window?.makeFirstResponder(targets[next])
    }

    func windowDidBecomeKey(_ notification: Notification) { updatePaneFocus() }
    func windowDidResignKey(_ notification: Notification) { updatePaneFocus() }

    private func updatePaneFocus() {
        let owner = focusOwner as? NSView
        let active = window?.isKeyWindow ?? false
        for pane in panes {
            let focused = owner?.isDescendant(of: pane) ?? false
            pane.focus = focused ? (active ? .active : .inactive) : .none
        }
    }

    /// The focused view; for a text field being edited, the field rather than its field editor.
    private var focusOwner: NSResponder? {
        guard let r = window?.firstResponder else { return nil }
        if let tv = r as? NSTextView, tv.isFieldEditor, let owner = tv.delegate as? NSResponder { return owner }
        return r
    }

    private var responderName: String {
        focusOwner.map { String(describing: type(of: $0)) } ?? "nil"
    }

    /// True when the diff or its find bar has keyboard focus.
    private var diffHasFocus: Bool {
        (focusOwner as? NSView)?.isDescendant(of: diffScroll) ?? false
    }

    private var fileListHasFocus: Bool {
        focusOwner === fileTable || focusOwner === fileFilter
    }

    private func findCommit(forward: Bool) {
        let query = searchField.stringValue
        guard !query.isEmpty else { return }
        if let i = Search.find(query, in: commits, from: commitTable.selectedRow, forward: forward) {
            selectCommit(i)
            showCount()
        } else {
            NSSound.beep()
            statusLabel.stringValue = "No match for “\(query)” · \(countText)"
        }
    }

    // MARK: - Loading

    private func startLoading(select hash: String?) {
        loader?.cancel()
        loadGen += 1
        let gen = loadGen
        commits = []
        rows = []
        pendingHash = hash
        commitTable.reloadData()
        statusLabel.stringValue = "Loading…"
        loadStart = Date()

        let loader = LogLoader(repo: workDir, args: args)
        self.loader = loader
        DispatchQueue.global(qos: .userInitiated).async {
            let result = loader.run { batch in
                DispatchQueue.main.async {
                    guard gen == self.loadGen else { return }
                    self.append(batch)
                }
            }
            DispatchQueue.main.async {
                guard gen == self.loadGen else { return }
                self.loadFinished(result)
            }
        }
    }

    private func append(_ batch: LogBatch) {
        let first = commits.count
        commits += batch.commits
        rows += batch.rows
        commitTable.noteNumberOfRowsChanged()
        if commitTable.selectedRow < 0 {
            if let hash = pendingHash {
                if let i = batch.commits.firstIndex(where: { $0.hash == hash }) {
                    pendingHash = nil
                    selectCommit(first + i)
                }
            } else {
                selectCommit(0)
            }
        }
        statusLabel.stringValue = "Loading… \(countText)"
    }

    private func loadFinished(_ result: GitResult) {
        let ms = Int(Date().timeIntervalSince(loadStart) * 1000)
        Log.info("loaded \(commits.count) commits in \(ms)ms")
        if pendingHash != nil && commitTable.selectedRow < 0 && !commits.isEmpty { selectCommit(0) }
        pendingHash = nil
        showCount()
        if result.status != 0 && !result.stopped {
            statusLabel.stringValue = "git log failed"
            let alert = NSAlert()
            alert.messageText = "git log failed"
            alert.informativeText = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            alert.beginSheetModal(for: window!)
        }
    }

    private var countText: String {
        commits.count == 1 ? "1 commit" : "\(commits.count.formatted()) commits"
    }

    private func showCount() {
        statusLabel.stringValue = countText
    }

    // MARK: - Selection and details

    private var selectedCommit: Commit? {
        let i = commitTable.selectedRow
        return i >= 0 && i < commits.count ? commits[i] : nil
    }

    private func selectCommit(_ i: Int) {
        commitTable.selectRowIndexes([i], byExtendingSelection: false)
        commitTable.scrollRowToVisible(i)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        if table === commitTable {
            hashLabel.stringValue = selectedCommit?.hash ?? ""
            if let c = selectedCommit { loadDetails(c.hash) }
        } else if table === fileTable {
            let row = fileTable.selectedRow
            guard row >= 0 else { return }
            scrollDiff(to: fileEntry(at: row)?.location ?? 0)
        }
    }

    private func loadDetails(_ hash: String) {
        detailsCancel?.cancel()
        let cancel = GitCancel()
        detailsCancel = cancel
        detailsGen += 1
        let gen = detailsGen
        let workDir = workDir
        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            let (details, result) = DetailsLoader.load(repo: workDir, hash: hash, cancel: cancel)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            DispatchQueue.main.async {
                guard gen == self.detailsGen else { return }
                if result.status != 0 && !result.stopped {
                    self.showDetailsError(result.stderr)
                } else {
                    self.show(details)
                    Log.info("details \(hash.prefix(12)): \(details.files.count) files, truncated=\(details.truncated), \(ms)ms")
                }
            }
        }
    }

    private func show(_ d: CommitDetails) {
        details = d
        render(d)
        diffView.scroll(.zero)
        applyFileFilter()
    }

    private func render(_ d: CommitDetails) {
        let text = NSMutableAttributedString(string: d.text, attributes: [
            .font: font, .foregroundColor: NSColor.textColor,
        ])
        for s in d.spans {
            let range = NSRange(location: s.location, length: s.length)
            switch s.kind {
            case .added: text.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: range)
            case .removed: text.addAttribute(.foregroundColor, value: NSColor.systemRed, range: range)
            case .hunk: text.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: range)
            case .fileHeader: text.addAttribute(.font, value: boldFont, range: range)
            }
        }
        diffView.textStorage?.setAttributedString(text)
    }

    private func showDetailsError(_ stderr: String) {
        details = nil
        diffView.textStorage?.setAttributedString(NSAttributedString(
            string: "git show failed:\n\n" + stderr,
            attributes: [.font: font, .foregroundColor: NSColor.systemRed]))
        applyFileFilter()
    }

    private func scrollDiff(to location: Int) {
        guard let lm = diffView.layoutManager, let tc = diffView.textContainer,
              location < diffView.string.utf16.count else { return }
        let glyphs = lm.glyphRange(forCharacterRange: NSRange(location: location, length: 1), actualCharacterRange: nil)
        lm.ensureLayout(forGlyphRange: glyphs)
        let rect = lm.boundingRect(forGlyphRange: glyphs, in: tc)
        diffView.scroll(NSPoint(x: 0, y: rect.minY))
    }

    private func pageDiff(up: Bool) {
        if up { diffView.scrollPageUp(nil) } else { diffView.scrollPageDown(nil) }
    }

    @objc private func copyHash(_ sender: Any?) {
        guard !hashLabel.stringValue.isEmpty else { return }
        copyToPasteboard(hashLabel.stringValue)
        // Brief checkmark so it's clear the copy happened.
        copyButton.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.copyButton.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy hash")
        }
    }

    private func copyToPasteboard(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    // MARK: - Table data

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === commitTable { return commits.count }
        guard details != nil else { return 0 }
        return visibleFiles.count + (showsCommitRow ? 1 : 0)
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let id = column?.identifier else { return nil }
        if tableView === fileTable {
            return textCell(tableView, id, fileEntry(at: row)?.path ?? "Commit", font: font, truncate: .byTruncatingHead)
        }
        let c = commits[row]
        switch id {
        case .subject:
            let cell = (tableView.makeView(withIdentifier: id, owner: nil) as? CommitCellView) ?? {
                let v = CommitCellView()
                v.identifier = id
                return v
            }()
            cell.commit = c
            cell.graph = rows[row]
            cell.font = font
            cell.labelFont = labelFont
            cell.labelBoldFont = labelBoldFont
            cell.needsDisplay = true
            return cell
        case .author:
            return textCell(tableView, id, c.author, font: font)
        default:
            return textCell(tableView, id, dateFormatter.string(from: c.date), font: font)
        }
    }
}

/// Split view that restores saved divider positions, or applies defaults.
final class SavedSplitView: NSSplitView {
    /// Divider positions; negative values count back from the far edge.
    var defaultPositions: [CGFloat] = []
    private var hadSavedFrames = false

    /// Call before the first layout: autosave writes frames as soon as it lays out.
    func enableAutosave(_ name: String) {
        hadSavedFrames = UserDefaults.standard.object(forKey: "NSSplitView Subview Frames \(name)") != nil
        autosaveName = name
    }

    func restoreOrSetDefaults() {
        guard !hadSavedFrames else { return }
        let length = isVertical ? bounds.width : bounds.height
        for (i, p) in defaultPositions.enumerated() { setPosition(p < 0 ? length + p : p, ofDividerAt: i) }
    }
}
