import SwiftUI
import AppKit
import Sparkle

@main
struct ClawdApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: ClawdController?
    var statusItem: NSStatusItem?
    var eventTap: CFMachPort?
    var localHotkeyMonitor: Any?
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = ClawdController()
        controller?.start()
        setupMenuBar()
        registerHotkey()
    }

    func registerHotkey() {
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            guard type == .keyDown else { return Unmanaged.passRetained(event) }
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if flags.contains(.maskCommand) && flags.contains(.maskShift) && keyCode == 49 {
                let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon!).takeUnretainedValue()
                DispatchQueue.main.async { delegate.togglePopover() }
                return nil
            }
            return Unmanaged.passRetained(event)
        }

        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        ) {
            eventTap = tap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func togglePopover() {
        guard let crab = controller?.crab else { return }
        if crab.panelOpen || (crab.popoverWindow?.isVisible ?? false) {
            crab.closePopover()
        } else {
            crab.openPopover()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.crab.session?.terminate()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 30)
        if let button = statusItem?.button {
            button.wantsLayer = true
            let crabLayer = CALayer()
            crabLayer.contents = renderMenuBarCrab().cgImage(forProposedRect: nil, context: nil, hints: nil)
            crabLayer.magnificationFilter = .nearest
            crabLayer.frame = CGRect(x: 3, y: 2, width: 24, height: 18)
            button.layer?.addSublayer(crabLayer)
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Show Clawd", action: #selector(toggleVisibility(_:)), keyEquivalent: "c")
        toggleItem.state = .on
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let chatMenu = NSMenu()
        let openChatItem = NSMenuItem(title: "Open", action: #selector(openChat), keyEquivalent: " ")
        openChatItem.keyEquivalentModifierMask = [.command, .shift]
        chatMenu.addItem(openChatItem)
        let newChatItem = NSMenuItem(title: "New Chat", action: #selector(newChat), keyEquivalent: "n")
        chatMenu.addItem(newChatItem)
        chatMenu.addItem(NSMenuItem.separator())
        let chatScreenItem = NSMenuItem(title: "Screen Context", action: #selector(toggleChatScreenContext(_:)), keyEquivalent: "")
        chatScreenItem.state = (ScreenContext.chatEnabled && ScreenContext.hasPermission) ? .on : .off
        chatMenu.addItem(chatScreenItem)
        let chatItem = NSMenuItem(title: "Chat", action: nil, keyEquivalent: "")
        chatItem.submenu = chatMenu
        menu.addItem(chatItem)

        let commentMenu = NSMenu()
        let commentToggle = NSMenuItem(title: "Enabled", action: #selector(toggleComments(_:)), keyEquivalent: "")
        commentToggle.state = .on
        commentMenu.addItem(commentToggle)
        commentMenu.addItem(NSMenuItem.separator())
        let commentScreenItem = NSMenuItem(title: "Screen Context", action: #selector(toggleCommentScreenContext(_:)), keyEquivalent: "")
        commentScreenItem.state = (ScreenContext.commentsEnabled && ScreenContext.hasPermission) ? .on : .off
        commentMenu.addItem(commentScreenItem)
        commentMenu.addItem(NSMenuItem.separator())
        for secs in [5, 10, 15, 30, 60, 120, 300] {
            let label = secs < 60 ? "\(secs)s" : "\(secs / 60)m"
            let item = NSMenuItem(title: "Every \(label)", action: #selector(setCommentInterval(_:)), keyEquivalent: "")
            item.tag = secs
            item.state = Int(CrabCharacter.commentInterval) == secs ? .on : .off
            commentMenu.addItem(item)
        }
        let commentItem = NSMenuItem(title: "Screen Comments", action: nil, keyEquivalent: "")
        commentItem.submenu = commentMenu
        menu.addItem(commentItem)

        let emotionMenu = NSMenu()
        let emotions: [(String, String)] = [
            ("😄 Happy", "😄"),
            ("😭 Sad", "😭"),
            ("😡 Angry", "😡"),
            ("😨 Fear", "😨"),
            ("🤢 Disgust", "🤢"),
            ("😴 Sleepy", "😴"),
            ("💀 Dead", "💀"),
            ("😍 Love", "😍"),
        ]
        for (label, id) in emotions {
            let item = NSMenuItem(title: label, action: #selector(playEmotion(_:)), keyEquivalent: "")
            item.representedObject = id
            emotionMenu.addItem(item)
        }
        let emotionItem = NSMenuItem(title: "Emotions", action: nil, keyEquivalent: "")
        emotionItem.submenu = emotionMenu
        menu.addItem(emotionItem)

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func renderMenuBarCrab() -> NSImage {
        let grid: [[Int]] = [
            [0,1,1,1,1,1,1,0],
            [0,1,2,1,1,2,1,0],
            [1,1,1,1,1,1,1,1],
            [0,1,1,1,1,1,1,0],
            [0,0,1,0,0,1,0,0],
        ]
        let rows = grid.count
        let cols = grid[0].count
        let px = 8
        let imgW = cols * px
        let imgH = rows * px

        guard let ctx = CGContext(
            data: nil, width: imgW, height: imgH,
            bitsPerComponent: 8, bytesPerRow: imgW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSImage(systemSymbolName: "ladybug.fill", accessibilityDescription: "Clawd")!
        }
        ctx.clear(CGRect(x: 0, y: 0, width: imgW, height: imgH))
        ctx.interpolationQuality = .none
        for row in 0..<rows {
            for col in 0..<cols {
                let val = grid[row][col]
                if val == 0 { continue }
                let flippedRow = rows - 1 - row
                if val == 1 {
                    ctx.setFillColor(red: 0.843, green: 0.467, blue: 0.341, alpha: 1)
                } else {
                    ctx.setFillColor(red: 0.176, green: 0.176, blue: 0.176, alpha: 1)
                }
                ctx.fill(CGRect(x: col * px, y: flippedRow * px, width: px, height: px))
            }
        }
        guard let cgImage = ctx.makeImage() else {
            return NSImage(systemSymbolName: "ladybug.fill", accessibilityDescription: "Clawd")!
        }
        let ptH: CGFloat = 18
        let ptW = ptH * CGFloat(imgW) / CGFloat(imgH)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: ptW, height: ptH))
        return image
    }

    @objc func toggleVisibility(_ sender: NSMenuItem) {
        guard let crab = controller?.crab else { return }
        if crab.window.isVisible {
            crab.window.orderOut(nil)
            crab.commentTimer?.invalidate()
            crab.commentTimer = nil
            sender.state = .off
            sender.title = "Show Clawd"
        } else {
            crab.window.orderFrontRegardless()
            crab.startCommentTimer()
            sender.state = .on
            sender.title = "Hide Clawd"
        }
    }

    @objc func toggleComments(_ sender: NSMenuItem) {
        guard let crab = controller?.crab else { return }
        if crab.commentTimer != nil {
            crab.commentTimer?.invalidate()
            crab.commentTimer = nil
            sender.state = .off
        } else {
            crab.startCommentTimer()
            sender.state = .on
        }
    }

    @objc func setCommentInterval(_ sender: NSMenuItem) {
        CrabCharacter.commentInterval = Double(sender.tag)
        if let menu = sender.menu {
            for item in menu.items where item.action == #selector(setCommentInterval(_:)) {
                item.state = item.tag == sender.tag ? .on : .off
            }
        }
        if let crab = controller?.crab, crab.commentTimer != nil {
            crab.startCommentTimer()
        }
    }

    @objc func toggleChatScreenContext(_ sender: NSMenuItem) {
        if !ScreenContext.hasPermission {
            ScreenContext.requestPermission()
        }
        ScreenContext.chatEnabled.toggle()
        sender.state = (ScreenContext.chatEnabled && ScreenContext.hasPermission) ? .on : .off
    }

    @objc func toggleCommentScreenContext(_ sender: NSMenuItem) {
        if !ScreenContext.hasPermission {
            ScreenContext.requestPermission()
        }
        ScreenContext.commentsEnabled.toggle()
        sender.state = (ScreenContext.commentsEnabled && ScreenContext.hasPermission) ? .on : .off
    }

    @objc func openChat() {
        togglePopover()
    }

    @objc func newChat() {
        controller?.crab.clearConversation()
    }

    @objc func playEmotion(_ sender: NSMenuItem) {
        guard let crab = controller?.crab, let emoji = sender.representedObject as? String else { return }
        crab.triggerEmotion(emoji)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
