import AppKit

final class TerminalView: NSView {
    let scrollView = NSScrollView()
    let textView = NSTextView()
    let inputField: NSTextField
    var onSendMessage: ((String) -> Void)?

    private let accentColor: NSColor
    private var isStreaming = false
    private var thinkingRange: NSRange?
    private var thinkingVerb = ""
    private var thinkingTimer: Timer?

    init(frame: NSRect, accentColor: NSColor) {
        self.accentColor = accentColor

        let cell = PaddedTextFieldCell(textCell: "")
        cell.isEditable = true
        cell.isScrollable = true
        cell.font = PetFonts.rounded(size: 13, weight: .medium)
        cell.textColor = PetTheme.ink
        cell.drawsBackground = false
        cell.isBezeled = false
        cell.fieldBackgroundColor = PetTheme.milk
        cell.fieldCornerRadius = 14
        cell.placeholderAttributedString = NSAttributedString(
            string: "Talk to Clawd...",
            attributes: [
                .font: PetFonts.rounded(size: 13, weight: .medium),
                .foregroundColor: PetTheme.ink.withAlphaComponent(0.3)
            ]
        )
        inputField = NSTextField(frame: .zero)
        inputField.cell = cell
        inputField.focusRingType = .none

        super.init(frame: frame)

        let inputH: CGFloat = 34
        let pad: CGFloat = 10

        inputField.frame = NSRect(x: pad, y: 6, width: frame.width - pad * 2, height: inputH)
        inputField.autoresizingMask = [.width]
        inputField.target = self
        inputField.action = #selector(inputSubmitted)
        addSubview(inputField)

        scrollView.frame = NSRect(
            x: pad, y: inputH + 12,
            width: frame.width - pad * 2,
            height: frame.height - inputH - 16
        )
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        textView.frame = scrollView.contentView.bounds
        textView.autoresizingMask = [.width]
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textColor = PetTheme.ink
        textView.font = PetFonts.rounded(size: 13, weight: .regular)
        textView.isRichText = true
        textView.textContainerInset = NSSize(width: 2, height: 4)
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = 6
        textView.defaultParagraphStyle = para
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        scrollView.documentView = textView
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { nil }

    @objc private func inputSubmitted() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.stringValue = ""
        isStreaming = true
        onSendMessage?(text)
    }

    private static let thinkVerbs = [
        "Thinking", "Pondering", "Brewing", "Noodling", "Simmering",
        "Crafting", "Percolating", "Mulling", "Hatching", "Crunching",
        "Tinkering", "Cogitating", "Musing", "Puzzling", "Booping",
        "Zigzagging", "Finagling", "Befuddling", "Caramelizing",
        "Meandering", "Computing", "Synthesizing", "Ruminating",
        "Orchestrating", "Manifesting", "Deciphering", "Transmuting",
    ]

    func showThinking() {
        removeThinking()
        ensureNewline()
        if needsClawdLabel {
            needsClawdLabel = false
            let para = NSMutableParagraphStyle()
            para.paragraphSpacingBefore = 12
            textView.textStorage?.append(NSAttributedString(string: "Clawd\n", attributes: [
                .font: PetFonts.rounded(size: 11, weight: .bold),
                .foregroundColor: PetTheme.ink.withAlphaComponent(0.35),
                .paragraphStyle: para
            ]))
        }
        thinkingVerb = Self.thinkVerbs.randomElement() ?? "Thinking"
        let text = "\u{00B7} \(thinkingVerb)\u{2026}"
        let start = textView.textStorage?.length ?? 0
        textView.textStorage?.append(NSAttributedString(string: text, attributes: thinkingAttrs()))
        thinkingRange = NSRange(location: start, length: text.count)
        scrollToBottom()

        thinkingTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            guard let self = self, let range = self.thinkingRange, let storage = self.textView.textStorage else { return }
            var next = Self.thinkVerbs.randomElement() ?? "Thinking"
            while next == self.thinkingVerb { next = Self.thinkVerbs.randomElement() ?? "Thinking" }
            self.thinkingVerb = next
            let newText = "\u{00B7} \(next)\u{2026}"
            if range.location + range.length <= storage.length {
                storage.replaceCharacters(in: range, with: NSAttributedString(string: newText, attributes: self.thinkingAttrs()))
                self.thinkingRange = NSRange(location: range.location, length: newText.count)
            }
        }
    }

    private func thinkingAttrs() -> [NSAttributedString.Key: Any] {
        [
            .font: PetFonts.rounded(size: 13, weight: .medium),
            .foregroundColor: accentColor.withAlphaComponent(0.5)
        ]
    }

    func removeThinking() {
        thinkingTimer?.invalidate()
        thinkingTimer = nil
        if let range = thinkingRange, let storage = textView.textStorage,
           range.location + range.length <= storage.length {
            storage.replaceCharacters(in: range, with: "")
        }
        thinkingRange = nil
    }

    private func ensureNewline() {
        if let storage = textView.textStorage, storage.length > 0, !storage.string.hasSuffix("\n") {
            storage.append(NSAttributedString(string: "\n"))
        }
    }

    private var needsClawdLabel = false

    func appendUser(_ text: String) {
        let spacer = NSMutableParagraphStyle()
        spacer.paragraphSpacingBefore = 12
        let labelPara = NSMutableParagraphStyle()
        labelPara.paragraphSpacingBefore = 12
        labelPara.alignment = .right
        let textPara = NSMutableParagraphStyle()
        textPara.alignment = .right
        ensureNewline()
        let block = NSMutableAttributedString()
        block.append(NSAttributedString(string: "You\n", attributes: [
            .font: PetFonts.rounded(size: 11, weight: .bold),
            .foregroundColor: accentColor.withAlphaComponent(0.5),
            .paragraphStyle: labelPara
        ]))
        block.append(NSAttributedString(string: "\(text)\n", attributes: [
            .font: PetFonts.rounded(size: 13, weight: .semibold),
            .foregroundColor: accentColor,
            .paragraphStyle: textPara
        ]))
        textView.textStorage?.append(block)
        needsClawdLabel = true
        scrollToBottom()
    }

    func appendProactive(_ text: String) {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = 12
        ensureNewline()
        let block = NSMutableAttributedString()
        block.append(NSAttributedString(string: "Clawd\n", attributes: [
            .font: PetFonts.rounded(size: 11, weight: .bold),
            .foregroundColor: PetTheme.ink.withAlphaComponent(0.35),
            .paragraphStyle: para
        ]))
        block.append(NSAttributedString(string: "\(text)\n", attributes: [
            .font: PetFonts.rounded(size: 12, weight: .regular),
            .foregroundColor: accentColor.withAlphaComponent(0.55),
        ]))
        textView.textStorage?.append(block)
        scrollToBottom()
    }

    func appendStreamingText(_ text: String) {
        if needsClawdLabel {
            needsClawdLabel = false
            let para = NSMutableParagraphStyle()
            para.paragraphSpacingBefore = 12
            textView.textStorage?.append(NSAttributedString(string: "Clawd\n", attributes: [
                .font: PetFonts.rounded(size: 11, weight: .bold),
                .foregroundColor: PetTheme.ink.withAlphaComponent(0.35),
                .paragraphStyle: para
            ]))
        }
        textView.textStorage?.append(NSAttributedString(string: text, attributes: [
            .font: PetFonts.rounded(size: 13, weight: .regular),
            .foregroundColor: PetTheme.ink
        ]))
        scrollToBottom()
    }

    func endStreaming() {
        if isStreaming {
            isStreaming = false
            ensureNewline()
        }
    }

    func appendError(_ text: String) {
        ensureNewline()
        textView.textStorage?.append(NSAttributedString(string: text + "\n", attributes: [
            .font: PetFonts.rounded(size: 12, weight: .medium),
            .foregroundColor: NSColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1.0)
        ]))
        scrollToBottom()
    }

    func appendToolUse(_ summary: String) {
        endStreaming()
        ensureNewline()
        textView.textStorage?.append(NSAttributedString(string: "  \(summary)\n", attributes: [
            .font: PetFonts.mono(size: 11, weight: .medium),
            .foregroundColor: accentColor.withAlphaComponent(0.5)
        ]))
        scrollToBottom()
    }

    func appendToolResult(_ summary: String, isError: Bool) {
        let color = isError
            ? NSColor(red: 0.85, green: 0.25, blue: 0.2, alpha: 1.0)
            : NSColor(red: 0.3, green: 0.65, blue: 0.4, alpha: 1.0)
        let mark = isError ? "\u{2717} " : "\u{2713} "
        let block = NSMutableAttributedString()
        block.append(NSAttributedString(string: "  \(mark)", attributes: [
            .font: PetFonts.mono(size: 11, weight: .bold), .foregroundColor: color
        ]))
        if !summary.isEmpty {
            block.append(NSAttributedString(string: "\(summary)\n", attributes: [
                .font: PetFonts.mono(size: 11, weight: .regular),
                .foregroundColor: PetTheme.ink.withAlphaComponent(0.4)
            ]))
        }
        textView.textStorage?.append(block)
        scrollToBottom()
    }

    func replayHistory(_ messages: [ChatMessage]) {
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        for msg in messages {
            switch msg.role {
            case .user:
                appendUser(msg.text)
            case .assistant:
                appendStreamingText(msg.text)
                ensureNewline()
            case .error:
                appendError(msg.text)
            case .toolUse:
                appendToolUse(msg.text)
            case .toolResult:
                let isErr = msg.text.hasPrefix("ERROR:")
                appendToolResult(msg.text, isError: isErr)
            }
        }
        scrollToBottom()
    }

    func clear() {
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
    }

    private func scrollToBottom() {
        textView.scrollToEndOfDocument(nil)
    }
}


final class ClickView: NSView {
    var onTap: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onTap?() }
}

final class PreviewCardView: NSView {
    var onTap: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = PetTheme.paper.cgColor
        layer?.cornerRadius = 14
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.08).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { nil }

    override func mouseDown(with event: NSEvent) { onTap?() }
}


// MARK: - Padded Input Cell

final class PaddedTextFieldCell: NSTextFieldCell {
    private let inset = NSSize(width: 10, height: 4)
    var fieldBackgroundColor: NSColor?
    var fieldCornerRadius: CGFloat = 4

    override var focusRingType: NSFocusRingType {
        get { .none }
        set {}
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        if let bg = fieldBackgroundColor {
            let path = NSBezierPath(roundedRect: cellFrame, xRadius: fieldCornerRadius, yRadius: fieldCornerRadius)
            bg.setFill()
            path.fill()
        }
        drawInterior(withFrame: cellFrame, in: controlView)
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        super.drawingRect(forBounds: rect).insetBy(dx: inset.width, dy: inset.height)
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        super.titleRect(forBounds: rect).insetBy(dx: inset.width, dy: inset.height)
    }

    private func configureEditor(_ textObj: NSText) {
        if let color = textColor { textObj.textColor = color }
        if let tv = textObj as? NSTextView {
            tv.insertionPointColor = textColor ?? .textColor
            tv.drawsBackground = false
            tv.backgroundColor = .clear
        }
        textObj.font = font
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        configureEditor(textObj)
        super.edit(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        configureEditor(textObj)
        super.select(withFrame: rect.insetBy(dx: inset.width, dy: inset.height), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}
