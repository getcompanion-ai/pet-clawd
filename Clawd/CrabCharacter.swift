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
    var popoverWindow: NSWindow?
    var terminalView: TerminalView?

    var clickOutsideMonitor: Any?
    var escapeMonitor: Any?

    var session: AgentSession?
    var isStartingSession = false
    var currentStreamingText = ""

    var bubbleWindow: NSWindow?
    var bubbleLabel: NSTextField?
    var lastPhraseUpdate: CFTimeInterval = 0
    var currentPhrase = ""

    var previewWindow: NSWindow?
    var previewTextView: NSTextView?
    var previewFadeTimer: Timer?

    var tapTimes: [CFTimeInterval] = []
    var emotionResetTimer: Timer?
    var tapDebounceTimer: Timer?
    var effectLayers: [CALayer] = []
    var commentTimer: Timer?
    var isAutoComment = false
    static var commentInterval: Double {
        get { UserDefaults.standard.double(forKey: "commentInterval").nonZero ?? 30 }
        set { UserDefaults.standard.set(newValue, forKey: "commentInterval") }
    }

    static let workspaceDir: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".clawd").appendingPathComponent("workspace")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    var lastFloorY: CGFloat = 0
    var lastDockX: CGFloat = 0
    var lastDockWidth: CGFloat = 800

    // MARK: - Setup

    func setup() {
        spriteRenderer = CrabSpriteRenderer()
        guard let screen = NSScreen.main else { return }
        let y = screen.frame.origin.y
        let startX = screen.frame.width / 2 - displaySize / 2

        window = NSWindow(contentRect: CGRect(x: startX, y: y, width: displaySize, height: displaySize),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = CrabContentView(frame: CGRect(x: 0, y: 0, width: displaySize, height: displaySize))
        host.character = self
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.addSublayer(spriteRenderer.layer)
        window.contentView = host
        window.orderFrontRegardless()
        lastTick = CACurrentMediaTime()

        if !ScreenContext.hasPermission {
            ScreenContext.requestPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if ScreenContext.hasPermission {
                    ScreenContext.enabled = true
                }
                self.startCommentTimer()
            }
        } else {
            ScreenContext.enabled = true
            startCommentTimer()
        }
    }

    // MARK: - Random Comments

    private static let hasLaunchedKey = "hasLaunchedBefore"

    func startCommentTimer() {
        commentTimer?.invalidate()
        if !UserDefaults.standard.bool(forKey: Self.hasLaunchedKey) {
            UserDefaults.standard.set(true, forKey: Self.hasLaunchedKey)
            commentTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                let greeting = "hey! i'm clawd. click me to chat, or grant screen access so i can see what you're up to and drop comments!"
                self.spriteRenderer.setFrame(.happy)
                self.bounce(count: 3, height: 8)
                self.showEffect(.sparkle)
                self.showPreview(greeting, autoFade: false)
                self.previewFadeTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
                    NSAnimationContext.runAnimationGroup({ ctx in
                        ctx.duration = 0.5
                        self?.previewWindow?.animator().alphaValue = 0
                    }, completionHandler: { self?.previewWindow?.orderOut(nil) })
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                    self?.spriteRenderer.setFrame(.idle)
                    self?.clearEffects()
                }
                self.scheduleNextComment()
            }
        } else {
            scheduleNextComment()
        }
    }

    private func scheduleNextComment() {
        commentTimer?.invalidate()
        let delay = Self.commentInterval
        commentTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.makeRandomComment()
        }
    }

    private func makeRandomComment() {
        guard !panelOpen,
              session?.isBusy != true,
              !isAutoComment,
              currentStreamingText.isEmpty,
              ScreenContext.enabled,
              ScreenContext.hasPermission else {
            scheduleNextComment()
            return
        }

        if session == nil {
            let newSession = createAgentSession()
            session = newSession
            wireSession(newSession)
            isStartingSession = true
            newSession.start()
        }

        ScreenContext.captureScreenshot { [weak self] screenshot in
            guard let self = self, let img = screenshot else {
                self?.scheduleNextComment()
                return
            }
            self.isAutoComment = true
            let seed = Int.random(in: 1000...9999)
            self.session?.send(
                message: "<system>[\(seed)] You're a chill friend sitting next to the user. Peek at their screen. Say one short casual sentence like you'd text a friend. Start with one emoji that fits your vibe: 😄 🥰 😮 😡 😢 😨 😏 😉</system>",
                screenshotBase64: img
            )
            self.scheduleNextComment()
        }
    }

    private var isAnimatingEmotion = false
    private var pendingTaps = 0

    func handleClick() {
        if panelOpen {
            closePopover()
            return
        }

        let now = CACurrentMediaTime()
        tapTimes.append(now)
        tapTimes = tapTimes.filter { now - $0 < 5.0 }.suffix(20).map { $0 }

        tapDebounceTimer?.invalidate()

        if tapTimes.count >= 2 {
            pendingTaps += 1
            if !isAnimatingEmotion {
                playNextEmotion()
            }
        } else {
            tapDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.tapTimes.count <= 1 && !self.isAnimatingEmotion {
                    self.tapTimes.removeAll()
                    self.openPopover()
                }
            }
        }
    }

    private func playNextEmotion() {
        guard pendingTaps > 0 else {
            isAnimatingEmotion = false
            return
        }
        pendingTaps = 0
        isAnimatingEmotion = true
        clearEffects()

        let count = tapTimes.count
        let mood: Int
        if count <= 4 { mood = 0 }
        else if count <= 8 { mood = 1 }
        else { mood = 2 }

        let duration: Double

        switch mood {
        case 0:
            let pick = [playHappy, playLove, playWink].randomElement()!
            duration = pick()
        case 1:
            let pick = [playSurprised, playScared, playSmug].randomElement()!
            duration = pick()
        default:
            let pick = [playAngry, playDead].randomElement()!
            duration = pick()
        }

        emotionResetTimer?.invalidate()
        emotionResetTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.spriteRenderer.setFrame(.idle)
            self.spriteRenderer.layer.transform = CATransform3DIdentity
            self.spriteRenderer.layer.opacity = 1
            self.clearEffects()

            if self.pendingTaps > 0 {
                self.playNextEmotion()
            } else {
                self.isAnimatingEmotion = false
            }
        }
    }

    private func playHappy() -> Double {
        spriteRenderer.setFrame(.happy)
        bounce(count: 3, height: 8)
        showEffect(.sparkle)
        return 1.8
    }

    private func playLove() -> Double {
        spriteRenderer.setFrame(.love)
        pulse(scale: 1.12, count: 2)
        showEffect(.heart)
        return 2.2
    }

    private func playWink() -> Double {
        spriteRenderer.setFrame(.wink)
        tilt(angle: 0.15, duration: 0.2)
        showEffect(.sparkle)
        return 1.5
    }

    private func playSurprised() -> Double {
        spriteRenderer.setFrame(.surprised)
        jump(height: 14)
        squash(scaleX: 1.2, scaleY: 0.8, duration: 0.12)
        showEffect(.sweat)
        return 1.6
    }

    private func playScared() -> Double {
        spriteRenderer.setFrame(.scared)
        tremble(intensity: 2, duration: 1.0)
        showEffect(.sweat)
        return 1.8
    }

    private func playSmug() -> Double {
        spriteRenderer.setFrame(.smug)
        tilt(angle: -0.1, duration: 0.3)
        return 1.5
    }

    private func playAngry() -> Double {
        spriteRenderer.setFrame(.angry)
        shake(intensity: 5, count: 12)
        showEffect(.angerMark)
        return 2.2
    }

    private func playDead() -> Double {
        spriteRenderer.setFrame(.dead)
        let layer = spriteRenderer.layer
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.5)
        layer.transform = CATransform3DConcat(
            CATransform3DMakeRotation(.pi / 2, 0, 0, 1),
            CATransform3DMakeTranslation(0, -20, 0)
        )
        layer.opacity = 0.4
        CATransaction.commit()
        showEffect(.skull)
        return 3.0
    }

    // MARK: - Pixel Art Effects

    enum EmotionEffect { case sparkle, heart, angerMark, sweat, skull }

    private func showEffect(_ effect: EmotionEffect) {
        let layer = spriteRenderer.layer
        let s = CGFloat(spriteRenderer.scale)

        switch effect {
        case .sparkle:
            addPixel(x: 2, y: 2, color: .white, on: layer, scale: s)
            addPixel(x: 13, y: 3, color: .white, on: layer, scale: s)
            addPixel(x: 3, y: 4, color: .white, on: layer, scale: s)
        case .heart:
            let c = NSColor.systemPink
            addPixel(x: 2, y: 1, color: c, on: layer, scale: s)
            addPixel(x: 4, y: 1, color: c, on: layer, scale: s)
            addPixel(x: 1, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 2, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 3, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 4, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 5, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 2, y: 3, color: c, on: layer, scale: s)
            addPixel(x: 3, y: 3, color: c, on: layer, scale: s)
            addPixel(x: 4, y: 3, color: c, on: layer, scale: s)
            addPixel(x: 3, y: 4, color: c, on: layer, scale: s)
        case .angerMark:
            let c = NSColor(red: 0.9, green: 0.2, blue: 0.15, alpha: 1)
            addPixel(x: 12, y: 1, color: c, on: layer, scale: s)
            addPixel(x: 14, y: 1, color: c, on: layer, scale: s)
            addPixel(x: 13, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 12, y: 3, color: c, on: layer, scale: s)
            addPixel(x: 14, y: 3, color: c, on: layer, scale: s)
            addPixel(x: 1, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 3, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 2, y: 3, color: c, on: layer, scale: s)
            addPixel(x: 1, y: 4, color: c, on: layer, scale: s)
            addPixel(x: 3, y: 4, color: c, on: layer, scale: s)
        case .sweat:
            let c = NSColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1)
            addPixel(x: 13, y: 3, color: c, on: layer, scale: s)
            addPixel(x: 13, y: 4, color: c, on: layer, scale: s)
            addPixel(x: 14, y: 5, color: c, on: layer, scale: s)
        case .skull:
            let c = NSColor.white.withAlphaComponent(0.6)
            addPixel(x: 1, y: 1, color: c, on: layer, scale: s)
            addPixel(x: 2, y: 1, color: c, on: layer, scale: s)
            addPixel(x: 1, y: 2, color: c, on: layer, scale: s)
            addPixel(x: 2, y: 2, color: c, on: layer, scale: s)
        }
    }

    private func addPixel(x: Int, y: Int, color: NSColor, on parent: CALayer, scale: CGFloat) {
        let px = CALayer()
        let flippedY = 15 - y
        px.frame = CGRect(x: CGFloat(x) * scale, y: CGFloat(flippedY) * scale, width: scale, height: scale)
        px.backgroundColor = color.cgColor
        parent.addSublayer(px)
        effectLayers.append(px)
    }

    private func clearEffects() {
        for l in effectLayers { l.removeFromSuperlayer() }
        effectLayers.removeAll()
    }

    // MARK: - Animation Primitives

    private func bounce(count: Int, height: CGFloat) {
        let origin = window.frame.origin
        var delay = 0.0
        for i in 0..<count {
            let h = height * max(1.0 - CGFloat(i) * 0.25, 0.2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.window.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + h))
            }
            delay += 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.window.setFrameOrigin(origin)
            }
            delay += 0.08
        }
    }

    private func jump(height: CGFloat) {
        let origin = window.frame.origin
        window.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + height))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.window.setFrameOrigin(origin)
        }
    }

    private func shake(intensity: CGFloat, count: Int) {
        let origin = window.frame.origin
        for i in 0..<count {
            let dx = (i % 2 == 0 ? intensity : -intensity) * max(1.0 - CGFloat(i) / CGFloat(count), 0.1)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.035) { [weak self] in
                self?.window.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(count) * 0.035) { [weak self] in
            self?.window.setFrameOrigin(origin)
        }
    }

    private func tremble(intensity: CGFloat, duration: Double) {
        let origin = window.frame.origin
        let steps = Int(duration / 0.03)
        for i in 0..<steps {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.03) { [weak self] in
                self?.window.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.window.setFrameOrigin(origin)
        }
    }

    private func squash(scaleX: CGFloat, scaleY: CGFloat, duration: Double) {
        let layer = spriteRenderer.layer
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        layer.transform = CATransform3DMakeScale(scaleX, scaleY, 1)
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration * 1.5)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            layer.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }

    private func pulse(scale: CGFloat, count: Int) {
        let layer = spriteRenderer.layer
        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = scale
        anim.duration = 0.25
        anim.autoreverses = true
        anim.repeatCount = Float(count)
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: "pulse")
    }

    private func tilt(angle: CGFloat, duration: Double) {
        let layer = spriteRenderer.layer
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        layer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.3) {
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration)
            layer.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }

    // MARK: - Popover

    func openPopover() {
        panelOpen = true
        isWalking = false
        isPaused = true
        spriteRenderer.stopWalkAnimation()
        hideBubble()
        hidePreview()

        if session == nil {
            let newSession = createAgentSession()
            session = newSession
            wireSession(newSession)
            isStartingSession = true
            newSession.start()
        }

        if popoverWindow == nil { createPopover() }

        if let terminal = terminalView, let session = session, !session.history.isEmpty {
            terminal.replayHistory(session.history)
        }

        positionPopover()
        popoverWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        popoverWindow?.makeKey()
        popoverWindow?.makeFirstResponder(terminalView?.inputField)

        removeMonitors()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            let mouse = NSEvent.mouseLocation
            let inPanel = self.popoverWindow?.frame.contains(mouse) ?? false
            let inChar = self.window.frame.contains(mouse)
            if !inPanel && !inChar { self.closePopover() }
        }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.closePopover(); return nil }
            return event
        }
    }

    func closePopover() {
        guard panelOpen else { return }
        popoverWindow?.orderOut(nil)
        removeMonitors()
        panelOpen = false

        if session?.isBusy == true {
            currentPhrase = ""
            lastPhraseUpdate = 0
        }

        pauseEndTime = CACurrentMediaTime() + Double.random(in: 2.0...4.0)
    }

    func createPopover() {
        let w: CGFloat = 300
        let h: CGFloat = 240

        let win = KeyableWindow(contentRect: CGRect(x: 0, y: 0, width: w, height: h),
                                styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let body = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        body.wantsLayer = true
        body.layer?.cornerRadius = 18
        body.layer?.shadowColor = NSColor.black.withAlphaComponent(0.12).cgColor
        body.layer?.shadowOpacity = 1
        body.layer?.shadowRadius = 16
        body.layer?.shadowOffset = CGSize(width: 0, height: -3)
        body.layer?.masksToBounds = false

        let inner = NSView(frame: body.bounds)
        inner.wantsLayer = true
        inner.layer?.backgroundColor = PetTheme.paper.cgColor
        inner.layer?.cornerRadius = 18
        inner.layer?.masksToBounds = true
        body.addSubview(inner)

        let terminal = TerminalView(frame: inner.bounds, accentColor: accent)
        terminal.autoresizingMask = [.width, .height]
        terminal.onSendMessage = { [weak self] message in
            self?.sendMessage(message)
        }
        inner.addSubview(terminal)

        win.contentView = body
        popoverWindow = win
        terminalView = terminal
    }

    func positionPopover() {
        guard let win = popoverWindow, let screen = NSScreen.main else { return }
        let cf = window.frame
        var x = cf.midX - win.frame.width / 2
        let y = cf.maxY - 14
        x = max(screen.frame.minX + 4, min(x, screen.frame.maxX - win.frame.width - 4))
        win.setFrameOrigin(NSPoint(x: x, y: min(y, screen.frame.maxY - win.frame.height - 4)))
    }

    // MARK: - Send

    private func sendMessage(_ text: String) {
        terminalView?.appendUser(text)
        terminalView?.showThinking()

        if session == nil {
            let newSession = createAgentSession()
            session = newSession
            wireSession(newSession)
            isStartingSession = true
            newSession.start()
        }

        let sendToSession: (String?) -> Void = { [weak self] screenshot in
            self?.session?.send(message: text, screenshotBase64: screenshot)
        }

        if ScreenContext.enabled {
            ScreenContext.captureScreenshot(completion: sendToSession)
        } else {
            sendToSession(nil)
        }
    }

    // MARK: - Session

    func wireSession(_ s: AgentSession) {
        s.onSessionReady = { [weak self] in
            self?.isStartingSession = false
        }

        s.onText = { [weak self] delta in
            guard let self = self else { return }
            if self.currentStreamingText.isEmpty && !self.isAutoComment {
                self.terminalView?.removeThinking()
            }
            self.currentStreamingText += delta

            if self.isAutoComment { return }

            self.terminalView?.appendStreamingText(delta)
            if !self.panelOpen {
                self.appendToPreview(delta)
            }
        }

        s.onTurnComplete = { [weak self] in
            guard let self = self else { return }
            let finalText = self.currentStreamingText.trimmingCharacters(in: .whitespacesAndNewlines)
            let wasAuto = self.isAutoComment
            self.isAutoComment = false
            self.currentStreamingText = ""

            if wasAuto {
                if !finalText.isEmpty {
                    let (emoji, comment) = self.parseEmotion(finalText)
                    self.showEmotion(emoji, forText: comment)
                    self.showPreview(comment, autoFade: true)
                    let display = emoji.isEmpty ? comment : "\(emoji) \(comment)"
                    self.terminalView?.appendProactive(display)
                    if let session = self.session,
                       let lastIdx = session.history.indices.last,
                       session.history[lastIdx].role == .assistant {
                        session.history[lastIdx] = ChatMessage(role: .assistant, text: comment)
                    }
                }
                return
            }

            self.terminalView?.endStreaming()
            if !self.panelOpen && !finalText.isEmpty {
                self.showPreview(finalText, autoFade: true)
            }
            self.hideBubble()
        }

        s.onError = { [weak self] text in
            self?.terminalView?.removeThinking()
            self?.terminalView?.appendError(text)
            self?.isStartingSession = false
            if self?.session?.isRunning == false {
                self?.session = nil
            }
        }

        s.onToolUse = { [weak self] name, input in
            let summary = ClaudeSession.formatToolSummary(name: name, input: input)
            self?.terminalView?.appendToolUse(summary)
        }

        s.onToolResult = { [weak self] summary, isError in
            self?.terminalView?.appendToolResult(summary, isError: isError)
        }

        s.onProcessExit = { [weak self] in
            self?.terminalView?.removeThinking()
            self?.terminalView?.endStreaming()
            self?.terminalView?.appendError("Session ended.")
            self?.isStartingSession = false
            self?.session = nil
        }
    }

    func clearConversation() {
        session?.terminate()
        session = nil
        isStartingSession = false
        currentStreamingText = ""
        terminalView?.clear()
        hideBubble()
        hidePreview()
    }

    private func removeMonitors() {
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m); clickOutsideMonitor = nil }
        if let m = escapeMonitor { NSEvent.removeMonitor(m); escapeMonitor = nil }
    }

    // MARK: - Emotions

    private static let emojiMap: [(String, CrabSpriteRenderer.Frame)] = [
        ("😄", .happy), ("😊", .happy), ("🥰", .love), ("😮", .surprised),
        ("😡", .angry), ("😢", .sad), ("😨", .scared), ("🤢", .angry),
        ("😏", .smug), ("😉", .wink), ("😴", .sleepy), ("🫥", .idle),
    ]

    private func parseEmotion(_ text: String) -> (String, String) {
        for (emoji, _) in Self.emojiMap {
            if text.hasPrefix(emoji) {
                let rest = String(text.dropFirst(emoji.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return (emoji, rest.isEmpty ? text : rest)
            }
        }
        return ("", text)
    }

    private func showEmotion(_ emoji: String, forText text: String = "") {
        clearEffects()
        let frame = Self.emojiMap.first(where: { $0.0 == emoji })?.1 ?? .idle
        spriteRenderer.setFrame(frame)

        switch frame {
        case .happy: bounce(count: 2, height: 6); showEffect(.sparkle)
        case .love: pulse(scale: 1.1, count: 2); showEffect(.heart)
        case .surprised: jump(height: 12)
        case .angry: shake(intensity: 5, count: 10); showEffect(.angerMark)
        case .sad: showEffect(.sweat)
        case .scared: tremble(intensity: 2, duration: 0.8); showEffect(.sweat)
        case .smug: tilt(angle: -0.1, duration: 0.3)
        case .wink: tilt(angle: 0.15, duration: 0.2)
        default: break
        }
        let words = text.split(separator: " ").count
        let dur = max(2.0, min(Double(words) * 0.8 + 1.5, 18.0))
        DispatchQueue.main.asyncAfter(deadline: .now() + dur) { [weak self] in
            guard let self = self, !self.isWalking else { return }
            self.spriteRenderer.setFrame(.idle)
            self.spriteRenderer.layer.transform = CATransform3DIdentity
            self.spriteRenderer.layer.opacity = 1
            self.clearEffects()
        }
    }

    // MARK: - Status Bubble (thinking phrases)

    private static let thinkPhrases = [
        "Thinking", "Pondering", "Reasoning", "Composing", "Computing",
        "Crafting", "Generating", "Imagining", "Mapping", "Mulling",
        "Synthesizing", "Processing", "Connecting", "Considering",
        "Contemplating", "Working", "Brewing", "Noodling", "Ruminating",
        "Percolating", "Simmering", "Marinating", "Hatching", "Tinkering",
        "Cogitating", "Ideating", "Musing", "Puzzling", "Orchestrating",
        "Deciphering", "Crystallizing", "Fermenting", "Incubating",
        "Forging", "Manifesting", "Crunching", "Calculating",
        "Cerebrating", "Zigzagging", "Caramelizing", "Booping",
        "Befuddling", "Finagling", "Canoodling", "Discombobulating",
        "Bloviating", "Boogieing", "Boondoggling", "Catapulting",
        "Transmuting", "Spinning", "Envisioning", "Burrowing",
    ]

    func updateStatusBubble() {
        let now = CACurrentMediaTime()

        if session?.isBusy == true && !panelOpen && !isAutoComment && currentStreamingText.isEmpty {
            if currentPhrase.isEmpty || now - lastPhraseUpdate > Double.random(in: 3.0...5.0) {
                var next = Self.thinkPhrases.randomElement() ?? "..."
                while next == currentPhrase && Self.thinkPhrases.count > 1 {
                    next = Self.thinkPhrases.randomElement() ?? "..."
                }
                currentPhrase = next
                lastPhraseUpdate = now
            }
            showBubble(text: currentPhrase)
        } else {
            hideBubble()
        }
    }

    func showBubble(text: String) {
        if bubbleWindow == nil { createBubble() }
        guard let win = bubbleWindow, let label = bubbleLabel else { return }

        let font = PetFonts.rounded(size: 11, weight: .semibold)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let bw = max(ceil(textSize.width) + 24, 48)
        let bh: CGFloat = 26

        let cf = window.frame
        let x = cf.midX - bw / 2
        let y = cf.maxY - 16
        win.setFrame(CGRect(x: x, y: y, width: bw, height: bh), display: false)

        if let container = win.contentView {
            container.frame = NSRect(x: 0, y: 0, width: bw, height: bh)
            label.stringValue = text
            label.font = font
            label.frame = NSRect(x: 0, y: 4, width: bw, height: 18)
        }

        if !win.isVisible {
            win.alphaValue = 1.0
            win.orderFrontRegardless()
        }
    }

    func hideBubble() {
        bubbleWindow?.orderOut(nil)
        currentPhrase = ""
    }

    func createBubble() {
        let w: CGFloat = 80
        let h: CGFloat = 26
        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: w, height: h),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = PetTheme.paper.withAlphaComponent(0.95).cgColor
        container.layer?.cornerRadius = h / 2
        container.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: "")
        label.font = PetFonts.rounded(size: 11, weight: .semibold)
        label.textColor = PetTheme.ink.withAlphaComponent(0.5)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 4, width: w, height: 18)
        container.addSubview(label)

        win.contentView = container
        bubbleWindow = win
        bubbleLabel = label
    }

    // MARK: - Response Preview

    private let previewW: CGFloat = 260
    private let previewPad: CGFloat = 10

    private func layoutPreview() {
        guard let tv = previewTextView,
              let win = previewWindow,
              let lm = tv.layoutManager,
              let tc = tv.textContainer else { return }
        let innerW = previewW - previewPad * 2
        tc.containerSize = NSSize(width: innerW, height: .greatestFiniteMagnitude)
        lm.ensureLayout(for: tc)
        let used = lm.usedRect(for: tc)
        let textH = ceil(used.height) + 8
        let ph = max(textH + previewPad * 2, 34)

        let cf = window.frame
        var x = cf.midX - previewW / 2
        if let s = NSScreen.main { x = max(s.frame.minX + 4, min(x, s.frame.maxX - previewW - 4)) }

        win.setFrame(CGRect(x: x, y: cf.maxY - 14, width: previewW, height: ph), display: true)
        tv.frame = NSRect(x: previewPad, y: previewPad, width: innerW, height: textH)
    }

    func appendToPreview(_ delta: String) {
        hideBubble()
        if previewWindow == nil { createPreview() }
        guard let tv = previewTextView, let win = previewWindow else { return }

        tv.textStorage?.append(NSAttributedString(string: delta, attributes: [
            .font: PetFonts.rounded(size: 13, weight: .regular),
            .foregroundColor: PetTheme.ink
        ]))
        layoutPreview()

        if !win.isVisible {
            win.alphaValue = 1
            win.orderFrontRegardless()
        }
    }

    func showPreview(_ text: String, autoFade: Bool) {
        previewFadeTimer?.invalidate()
        previewFadeTimer = nil
        hideBubble()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if previewWindow == nil { createPreview() }
        guard let tv = previewTextView, let win = previewWindow else { return }

        tv.textStorage?.setAttributedString(renderPreviewMarkdown(trimmed))
        layoutPreview()

        win.alphaValue = 1
        win.orderFrontRegardless()

        if autoFade {
            let words = trimmed.split(separator: " ").count
            let dur = max(3.0, min(Double(words) * 0.8 + 2.0, 20.0))
            previewFadeTimer = Timer.scheduledTimer(withTimeInterval: dur, repeats: false) { [weak self] _ in
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.5
                    self?.previewWindow?.animator().alphaValue = 0
                }, completionHandler: { self?.previewWindow?.orderOut(nil) })
            }
        }
    }

    private func renderPreviewMarkdown(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = PetFonts.rounded(size: 13, weight: .regular)
        let boldFont = PetFonts.rounded(size: 13, weight: .bold)
        let codeFont = PetFonts.mono(size: 12, weight: .regular)
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var codeLines: [String] = []

        for (i, line) in lines.enumerated() {
            let suffix = i < lines.count - 1 ? "\n" : ""

            if line.hasPrefix("```") {
                if inCodeBlock {
                    let code = codeLines.joined(separator: "\n")
                    result.append(NSAttributedString(string: code + "\n", attributes: [
                        .font: codeFont, .foregroundColor: PetTheme.ink,
                        .backgroundColor: PetTheme.milk
                    ]))
                    inCodeBlock = false
                    codeLines = []
                } else {
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock { codeLines.append(line); continue }

            if line.hasPrefix("# ") {
                result.append(NSAttributedString(string: String(line.dropFirst(2)) + suffix, attributes: [
                    .font: PetFonts.rounded(size: 14, weight: .bold), .foregroundColor: accent
                ]))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                result.append(NSAttributedString(string: "  \u{2022} " + String(line.dropFirst(2)) + suffix, attributes: [
                    .font: font, .foregroundColor: PetTheme.ink
                ]))
            } else {
                result.append(renderInline(line + suffix, font: font, boldFont: boldFont, codeFont: codeFont))
            }
        }

        if inCodeBlock && !codeLines.isEmpty {
            result.append(NSAttributedString(string: codeLines.joined(separator: "\n") + "\n", attributes: [
                .font: codeFont, .foregroundColor: PetTheme.ink, .backgroundColor: PetTheme.milk
            ]))
        }

        return result
    }

    private func renderInline(_ text: String, font: NSFont, boldFont: NSFont, codeFont: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "`" {
                let after = text.index(after: i)
                if after < text.endIndex, let close = text[after...].firstIndex(of: "`") {
                    result.append(NSAttributedString(string: String(text[after..<close]), attributes: [
                        .font: codeFont, .foregroundColor: accent, .backgroundColor: PetTheme.milk
                    ]))
                    i = text.index(after: close); continue
                }
            }
            if text[i] == "*", text.index(after: i) < text.endIndex, text[text.index(after: i)] == "*" {
                let start = text.index(i, offsetBy: 2)
                if start < text.endIndex, let range = text.range(of: "**", range: start..<text.endIndex) {
                    result.append(NSAttributedString(string: String(text[start..<range.lowerBound]), attributes: [
                        .font: boldFont, .foregroundColor: PetTheme.ink
                    ]))
                    i = range.upperBound; continue
                }
            }
            result.append(NSAttributedString(string: String(text[i]), attributes: [
                .font: font, .foregroundColor: PetTheme.ink
            ]))
            i = text.index(after: i)
        }
        return result
    }

    func hidePreview() {
        previewFadeTimer?.invalidate()
        previewFadeTimer = nil
        previewWindow?.orderOut(nil)
    }

    func createPreview() {
        let pw: CGFloat = 260
        let ph: CGFloat = 40

        let win = NSWindow(contentRect: CGRect(x: 0, y: 0, width: pw, height: ph),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let card = PreviewCardView(frame: NSRect(x: 0, y: 0, width: pw, height: ph))
        card.onTap = { [weak self] in self?.hidePreview() }

        let tv = NSTextView(frame: NSRect(x: 10, y: 10, width: pw - 20, height: ph - 20))
        tv.isEditable = false
        tv.isSelectable = false
        tv.backgroundColor = .clear
        tv.isRichText = true
        tv.textContainerInset = NSSize(width: 0, height: 0)
        tv.textContainer?.lineFragmentPadding = 0
        tv.textContainer?.widthTracksTextView = false
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        card.addSubview(tv)

        win.contentView = card
        previewWindow = win
        previewTextView = tv
    }

    // MARK: - Walking

    var walkPixelX: CGFloat = 0
    var walkTargetX: CGFloat = 0
    let walkSpeed: CGFloat = 60

    func startWalk() {
        let cf = window.frame
        let curX = cf.origin.x
        let margin: CGFloat = 4
        let leftEdge = lastDockX + margin
        let rightEdge = lastDockX + lastDockWidth - displaySize - margin

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

    func update(floorY: CGFloat, dockX: CGFloat, dockWidth: CGFloat) {
        lastFloorY = floorY
        lastDockX = dockX
        lastDockWidth = dockWidth
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

        if panelOpen {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: floorY))
            positionPopover()
            return
        }

        if isPaused {
            if now >= pauseEndTime {
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
            window.setFrameOrigin(NSPoint(x: walkPixelX, y: floorY))
        }

        updateStatusBubble()

        if let pw = previewWindow, pw.isVisible {
            let cf = window.frame
            let ps = pw.frame.size
            var px = cf.midX - ps.width / 2
            if let s = NSScreen.main { px = max(s.frame.minX + 4, min(px, s.frame.maxX - ps.width - 4)) }
            pw.setFrameOrigin(NSPoint(x: px, y: cf.maxY - 14))
        }
    }
}

// MARK: - Support

class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

enum PetTheme {
    static let shell = NSColor(red: 0.843, green: 0.467, blue: 0.341, alpha: 1.0)
    static let paper = NSColor(red: 0.980, green: 0.944, blue: 0.902, alpha: 1.0)
    static let milk = NSColor(red: 0.996, green: 0.988, blue: 0.972, alpha: 1.0)
    static let blush = NSColor(red: 0.972, green: 0.820, blue: 0.760, alpha: 1.0)
    static let ink = NSColor(red: 0.188, green: 0.156, blue: 0.141, alpha: 1.0)
}

enum PetFonts {
    static func rounded(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    static func mono(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }
}
