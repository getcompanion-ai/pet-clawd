import AppKit

class CrabCharacter {
    var window: NSWindow!
    var spriteRenderer: CrabSpriteRenderer!
    weak var controller: ClawdController?

    let displaySize: CGFloat = 80

    var isWalking = false
    var isPaused = true
    var pauseEndTime: CFTimeInterval = 0
    var goingRight = true

    var blinkTimer: CFTimeInterval = 0
    var nextBlink: CFTimeInterval = 3.0
    var isBlinking = false
    var lastTick: CFTimeInterval = 0

    let accent = NSColor(red: 0.843, green: 0.467, blue: 0.341, alpha: 1.0)

    var panelOpen = false
    var panelWindow: NSWindow?
    var panelHistory: NSTextView?
    var panelInput: NSTextField?

    var pillWindow: NSWindow?
    var pillLabel: NSTextField?
    var pillFadeTimer: Timer?

    var clickOutsideMonitor: Any?
    var escapeMonitor: Any?

    var session: AgentSession?
    var responseText = ""
    var isStreaming = false

    var dotTimer: Timer?
    var dotCount = 0
    var isDragged = false
    var customY: CGFloat?


    static let workspaceDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".clawd").appendingPathComponent("workspace")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Setup

    var lastFloorY: CGFloat = 0
    var lastScreenLeft: CGFloat = 0
    var lastScreenWidth: CGFloat = 1440

    func setup() {
        spriteRenderer = CrabSpriteRenderer()
        guard let screen = NSScreen.main else { return }
        let y = screen.frame.origin.y

        window = NSWindow(contentRect: CGRect(x: 0, y: y, width: displaySize, height: displaySize),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let host = CrabContentView(frame: CGRect(x: 0, y: 0, width: displaySize, height: displaySize))
        host.character = self
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.addSublayer(spriteRenderer.layer)
        window.contentView = host
        window.orderFrontRegardless()
        lastTick = CACurrentMediaTime()
    }

    func handleClick() {
        if panelOpen { closePanel() }
        else { openPanel() }
    }

    // MARK: - Panel

    func openPanel() {
        panelOpen = true
        isWalking = false
        isPaused = true
        spriteRenderer.stopWalkAnimation()
        hidePill()

        if panelWindow == nil { createPanel() }
        positionPanel()
        panelWindow?.orderFrontRegardless()
        panelWindow?.makeKey()
        panelWindow?.makeFirstResponder(panelInput)
        panelHistory?.scrollToEndOfDocument(nil)

        removeMonitors()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let mouse = NSEvent.mouseLocation
            let inPanel = self.panelWindow?.frame.contains(mouse) ?? false
            let inChar = self.window.frame.contains(mouse)
            if !inPanel && !inChar { self.closePanel() }
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closePanel(); return nil }
            return event
        }
    }

    func closePanel() {
        guard panelOpen else { return }
        panelWindow?.orderOut(nil)
        removeMonitors()
        panelOpen = false
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 2.0...4.0)
    }

    func createPanel() {
        let w: CGFloat = 320
        let h: CGFloat = 300
        let inputH: CGFloat = 42

        let win = KeyableWindow(contentRect: CGRect(x: 0, y: 0, width: w, height: h),
                                styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 10)
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        blur.material = .popover
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 14
        blur.layer?.masksToBounds = true

        let scroll = NSScrollView(frame: NSRect(x: 0, y: inputH, width: w, height: h - inputH))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.scrollerStyle = .overlay

        let tv = NSTextView(frame: scroll.contentView.bounds)
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 12, height: 12)
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        blur.addSubview(scroll)

        let field = NSTextField(frame: NSRect(x: 14, y: 10, width: w - 46, height: 22))
        field.font = .systemFont(ofSize: 13)
        field.placeholderString = "Ask anything..."
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.target = self
        field.action = #selector(handleSend)
        blur.addSubview(field)

        let btn = NSButton(frame: NSRect(x: w - 30, y: 11, width: 20, height: 20))
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.contentTintColor = accent
        btn.image = NSImage(systemSymbolName: "arrow.up.circle.fill", accessibilityDescription: "Send")
        btn.imageScaling = .scaleProportionallyUpOrDown
        btn.target = self
        btn.action = #selector(handleSend)
        blur.addSubview(btn)

        win.contentView = blur
        panelWindow = win
        panelHistory = tv
        panelInput = field
    }

    func positionPanel() {
        guard let win = panelWindow, let screen = NSScreen.main else { return }
        let cf = window.frame
        var x = cf.midX - win.frame.width / 2
        let y = cf.maxY + 8
        x = max(screen.frame.minX + 4, min(x, screen.frame.maxX - win.frame.width - 4))
        win.setFrameOrigin(NSPoint(x: x, y: min(y, screen.frame.maxY - win.frame.height - 4)))
    }

    // MARK: - Send

    @objc func handleSend() {
        guard let text = panelInput?.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }
        panelInput?.stringValue = ""
        panelInput?.isEnabled = false

        appendUser(text)

        if session == nil {
            let s = ClaudeSession()
            session = s
            wireSession(s)
            s.start()
        }

        startDots()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            if ScreenContext.enabled {
                ScreenContext.captureScreenshot { [weak self] base64 in
                    self?.session?.send(message: text, screenshotBase64: base64)
                }
            } else {
                self.session?.send(message: text, screenshotBase64: nil)
            }
        }
    }

    // MARK: - Panel rendering

    private func appendUser(_ text: String) {
        guard let tv = panelHistory, let storage = tv.textStorage else { return }

        let font = NSFont.systemFont(ofSize: 13)
        let maxW: CGFloat = 200
        let hPad: CGFloat = 12
        let vPad: CGFloat = 8
        let drawAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textRect = (text as NSString).boundingRect(
            with: NSSize(width: maxW, height: 10000),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: drawAttrs)
        let bw = ceil(textRect.width) + hPad * 2
        let bh = ceil(textRect.height) + vPad * 2

        let img = NSImage(size: NSSize(width: bw, height: bh), flipped: true) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
            NSColor(red: 0.843, green: 0.467, blue: 0.341, alpha: 1.0).setFill()
            path.fill()
            (text as NSString).draw(with: NSRect(x: hPad, y: vPad, width: maxW, height: bh),
                                    options: [.usesLineFragmentOrigin], attributes: drawAttrs)
            return true
        }

        let attachment = NSTextAttachment()
        attachment.attachmentCell = NSTextAttachmentCell(imageCell: img)
        let para = NSMutableParagraphStyle()
        para.alignment = .right
        para.paragraphSpacing = 8
        let line = NSMutableAttributedString(attachment: attachment)
        line.append(NSAttributedString(string: "\n"))
        line.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: line.length))
        storage.append(line)
        tv.scrollToEndOfDocument(nil)
    }

    private func appendAIText(_ text: String) {
        guard let tv = panelHistory else { return }
        let para = NSMutableParagraphStyle()
        para.alignment = .left
        para.lineSpacing = 2
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para,
        ]
        tv.textStorage?.append(NSAttributedString(string: text, attributes: attrs))
        tv.scrollToEndOfDocument(nil)
    }

    // MARK: - Thinking bubble

    var thinkingBubble: NSWindow?
    var thinkingLabel: NSTextField?

    func startDots() {
        dotCount = 0
        if panelOpen { appendAIText("...") }
        showThinkingBubble()
        dotTimer?.invalidate()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.dotCount = (self.dotCount + 1) % 3
            self.thinkingLabel?.stringValue = String(repeating: ".", count: self.dotCount + 1)
            self.positionThinkingBubble()
        }
    }

    func stopDots() {
        dotTimer?.invalidate()
        dotTimer = nil
        thinkingBubble?.orderOut(nil)
    }

    func showThinkingBubble() {
        if thinkingBubble == nil {
            let w: CGFloat = 44
            let h: CGFloat = 28
            let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: w, height: h),
                               styleMask: .borderless, backing: .buffered, defer: false)
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 3)
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .stationary]

            let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: w, height: h))
            blur.material = .popover
            blur.state = .active
            blur.wantsLayer = true
            blur.layer?.cornerRadius = h / 2
            blur.layer?.masksToBounds = true

            let label = NSTextField(labelWithString: "...")
            label.font = .systemFont(ofSize: 14, weight: .bold)
            label.textColor = .secondaryLabelColor
            label.alignment = .center
            label.frame = NSRect(x: 0, y: 4, width: w, height: 18)
            blur.addSubview(label)

            win.contentView = blur
            thinkingBubble = win
            thinkingLabel = label
        }
        positionThinkingBubble()
        thinkingBubble?.orderFrontRegardless()
    }

    func positionThinkingBubble() {
        guard let tb = thinkingBubble else { return }
        let cf = window.frame
        let bw = tb.frame.width
        tb.setFrameOrigin(NSPoint(x: cf.midX - bw / 2, y: cf.maxY + 4))
    }

    // MARK: - Session

    func wireSession(_ s: AgentSession) {
        s.onText = { [weak self] delta in
            guard let self = self else { return }

            if !self.isStreaming {
                self.isStreaming = true
                self.stopDots()
                if self.panelOpen, let storage = self.panelHistory?.textStorage {
                    let s = storage.string
                    if s.hasSuffix("...\n") || s.hasSuffix("...") || s.hasSuffix("..\n") || s.hasSuffix(".\n") {
                        var removeFrom = storage.length
                        let chars = Array(s)
                        while removeFrom > 0 && (chars[removeFrom - 1] == "." || chars[removeFrom - 1] == "\n") {
                            removeFrom -= 1
                        }
                        if removeFrom < storage.length {
                            storage.deleteCharacters(in: NSRange(location: removeFrom, length: storage.length - removeFrom))
                        }
                    }
                }
            }

            self.responseText += delta

            if self.panelOpen {
                self.appendAIText(delta)
            } else {
                self.showPillText(self.responseText, autoFade: false)
            }
        }

        s.onTurnComplete = { [weak self] in
            guard let self = self else { return }
            self.stopDots()
            self.isStreaming = false

            if self.panelOpen {
                self.appendAIText("\n\n")
            } else if !self.responseText.isEmpty {
                self.showPillText(self.responseText, autoFade: true)
            }

            self.responseText = ""
            self.panelInput?.isEnabled = true
            if self.panelOpen {
                self.panelWindow?.makeFirstResponder(self.panelInput)
            }
        }

        s.onError = { [weak self] text in
            self?.stopDots()
            self?.isStreaming = false
            if self?.panelOpen == true {
                self?.appendAIText(text + "\n\n")
            } else {
                self?.showPillText(text, autoFade: true)
            }
            self?.responseText = ""
            self?.panelInput?.isEnabled = true
        }

        s.onToolUse = { _, _ in }
        s.onToolResult = { _, _ in }
        s.onProcessExit = { [weak self] in
            self?.stopDots()
            self?.isStreaming = false
            self?.panelInput?.isEnabled = true
        }
    }

    private func removeMonitors() {
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
        if let m = escapeMonitor { NSEvent.removeMonitor(m); escapeMonitor = nil }
    }

    // MARK: - Pill

    func showPillText(_ text: String, autoFade: Bool) {
        pillFadeTimer?.invalidate()
        pillFadeTimer = nil
        if pillWindow == nil { createPill() }
        guard let label = pillLabel, let pill = pillWindow else { return }

        label.stringValue = text
        label.preferredMaxLayoutWidth = 270
        let fit = label.fittingSize
        let pw = min(max(fit.width + 24, 60), 300)
        let ph = min(fit.height + 16, 160)

        let cf = window.frame
        var x = cf.midX - pw / 2
        if let s = NSScreen.main { x = max(s.frame.minX + 4, min(x, s.frame.maxX - pw - 4)) }

        pill.setFrame(CGRect(x: x, y: cf.maxY + 6, width: pw, height: ph), display: true)
        label.frame = NSRect(x: 12, y: 8, width: pw - 24, height: ph - 16)
        if let blur = pill.contentView as? NSVisualEffectView {
            blur.frame = NSRect(x: 0, y: 0, width: pw, height: ph)
        }
        pill.alphaValue = 1
        pill.orderFrontRegardless()

        if autoFade {
            let dur = max(4.0, min(Double(text.count) * 0.05, 12.0))
            pillFadeTimer = Timer.scheduledTimer(withTimeInterval: dur, repeats: false) { [weak self] _ in
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.4
                    self?.pillWindow?.animator().alphaValue = 0
                }, completionHandler: { self?.pillWindow?.orderOut(nil) })
            }
        }
    }

    func hidePill() {
        pillFadeTimer?.invalidate()
        pillFadeTimer = nil
        pillWindow?.orderOut(nil)
    }

    func createPill() {
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 100, height: 40),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 5)
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let blur = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
        blur.material = .popover
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true

        let label = NSTextField(wrappingLabelWithString: "")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.isEditable = false
        label.isSelectable = true
        label.drawsBackground = false
        label.isBordered = false
        label.maximumNumberOfLines = 0
        blur.addSubview(label)

        let click = BubbleClickView(frame: blur.bounds)
        click.autoresizingMask = [.width, .height]
        click.onTap = { [weak self] in self?.hidePill(); self?.openPanel() }
        blur.addSubview(click)

        win.contentView = blur
        pillWindow = win
        pillLabel = label
    }

    // MARK: - Drag & Snap

    var velX: CGFloat = 0
    var velY: CGFloat = 0
    var isFalling = false
    var fallTargetY: CGFloat = 0
    let gravity: CGFloat = 2400
    let restitution: CGFloat = 0.5
    let friction: CGFloat = 0.99
    var isThrown = false

    func snapToSurface() {
        fallTargetY = lastFloorY
        velX = 0
        velY = 0
        isFalling = true
        isThrown = false
        isDragged = true
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 4.0...8.0)
    }

    func throwWithVelocity(vx: CGFloat, vy: CGFloat) {
        fallTargetY = lastFloorY

        let scale: CGFloat = 0.8
        velX = vx * scale
        velY = vy * scale
        isFalling = true
        isThrown = true
        isDragged = true
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + 99999
    }

    // MARK: - Walking

    var walkPixelX: CGFloat = 0
    var walkTargetX: CGFloat = 0
    let walkSpeed: CGFloat = 60

    func startWalk() {
        let cf = window.frame
        let curX = cf.origin.x

        let margin: CGFloat = 10
        let leftEdge = lastScreenLeft + margin
        let rightEdge = lastScreenLeft + lastScreenWidth - displaySize - margin

        if curX >= rightEdge - 20 {
            goingRight = false
        } else if curX <= leftEdge + 20 {
            goingRight = true
        } else {
            goingRight = Bool.random()
        }

        let walkDist = CGFloat.random(in: 80...200)
        walkPixelX = curX

        if goingRight {
            walkTargetX = min(curX + walkDist, rightEdge)
        } else {
            walkTargetX = max(curX - walkDist, leftEdge)
        }

        isPaused = false
        isWalking = true
        spriteRenderer.setFlipped(!goingRight)
        spriteRenderer.startWalkAnimation()
    }

    func enterPause() {
        isWalking = false
        isPaused = true
        spriteRenderer.stopWalkAnimation()
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 4.0...10.0)
    }

    func triggerFall() {
        isWalking = false
        spriteRenderer.stopWalkAnimation()
        fallTargetY = lastFloorY
        velX = 0
        velY = 0
        isFalling = true
        isDragged = true
        isPaused = true
        pauseEndTime = CACurrentMediaTime() + Double.random(in: 3.0...6.0)
    }

    func update(floorY: CGFloat, screenLeft: CGFloat, screenWidth: CGFloat) {
        lastFloorY = floorY
        lastScreenLeft = screenLeft
        lastScreenWidth = screenWidth
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now

        blinkTimer += dt
        if !isBlinking && blinkTimer > nextBlink {
            isBlinking = true; blinkTimer = 0; spriteRenderer.setFrame(.blink)
        }
        if isBlinking && blinkTimer > 0.15 {
            isBlinking = false; blinkTimer = 0; nextBlink = 2 + Double.random(in: 0...4)
            if !isWalking { spriteRenderer.setFrame(.idle) }
        }

        if isFalling {
            fallTargetY = floorY
            let dtF = CGFloat(dt)

            velY -= gravity * dtF
            velX *= friction

            var curX = window.frame.origin.x + velX * dtF
            var curY = window.frame.origin.y + velY * dtF

            if let screen = NSScreen.main {
                let minX = screen.frame.minX
                let maxX = screen.frame.maxX - displaySize
                let maxY = screen.frame.maxY - displaySize

                if curX < minX { curX = minX; velX = -velX * restitution }
                if curX > maxX { curX = maxX; velX = -velX * restitution }
                if curY > maxY { curY = maxY; velY = -abs(velY) * restitution }
            }

            if curY <= fallTargetY {
                curY = fallTargetY
                if abs(velY) > 20 || abs(velX) > 20 {
                    velY = abs(velY) * restitution
                    velX *= 0.8
                } else {
                    isFalling = false
                    isThrown = false
                    velX = 0
                    velY = 0
                    customY = fallTargetY
                    walkPixelX = curX
                    pauseEndTime = CACurrentMediaTime() + Double.random(in: 3.0...6.0)
                }
            }

            window.setFrameOrigin(NSPoint(x: curX, y: curY))
            return
        }

        if panelOpen {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: customY ?? floorY))
            positionPanel()
            return
        }

        if isPaused {
            if now >= pauseEndTime {
                if isDragged { isDragged = false }
                startWalk()
            }
            return
        }

        if isWalking {
            let step = walkSpeed * CGFloat(dt)
            if goingRight {
                walkPixelX += step
                if walkPixelX >= walkTargetX { walkPixelX = walkTargetX; enterPause() }
            } else {
                walkPixelX -= step
                if walkPixelX <= walkTargetX { walkPixelX = walkTargetX; enterPause() }
            }

            window.setFrameOrigin(NSPoint(x: walkPixelX, y: customY ?? floorY))

        }

        if pillWindow?.isVisible ?? false {
            let cf = window.frame
            let ps = pillWindow!.frame.size
            var px = cf.midX - ps.width / 2
            if let s = NSScreen.main { px = max(s.frame.minX + 4, min(px, s.frame.maxX - ps.width - 4)) }
            pillWindow?.setFrameOrigin(NSPoint(x: px, y: cf.maxY + 6))
        }
    }
}

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class BubbleClickView: NSView {
    var onTap: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onTap?() }
}
