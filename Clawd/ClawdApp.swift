import SwiftUI
import AppKit

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = renderMenuBarCrab()
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Show Clawd", action: #selector(toggleVisibility(_:)), keyEquivalent: "c")
        toggleItem.state = .on
        menu.addItem(toggleItem)

        let chatItem = NSMenuItem(title: "Open Chat", action: #selector(openChat), keyEquivalent: " ")
        chatItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(chatItem)

        let newChatItem = NSMenuItem(title: "New Chat", action: #selector(newChat), keyEquivalent: "n")
        menu.addItem(newChatItem)

        menu.addItem(NSMenuItem.separator())

        let screenItem = NSMenuItem(title: "Screen Context", action: #selector(toggleScreenContext(_:)), keyEquivalent: "")
        screenItem.state = ScreenContext.enabled ? .on : .off
        menu.addItem(screenItem)

        let commentMenu = NSMenu()
        let commentToggle = NSMenuItem(title: "Enabled", action: #selector(toggleComments(_:)), keyEquivalent: "")
        commentToggle.state = .on
        commentMenu.addItem(commentToggle)
        commentMenu.addItem(NSMenuItem.separator())
        for secs in [15, 30, 60, 120, 300] {
            let label = secs < 60 ? "\(secs)s" : "\(secs / 60)m"
            let item = NSMenuItem(title: "Every \(label)", action: #selector(setCommentInterval(_:)), keyEquivalent: "")
            item.tag = secs
            item.state = Int(CrabCharacter.commentInterval) == secs ? .on : .off
            commentMenu.addItem(item)
        }
        let commentItem = NSMenuItem(title: "Random Comments", action: nil, keyEquivalent: "")
        commentItem.submenu = commentMenu
        menu.addItem(commentItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func renderMenuBarCrab() -> NSImage {
        let grid: [[Int]] = [
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
            [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
            [0,0,0,1,1,2,2,1,1,2,2,1,1,0,0,0],
            [0,0,0,1,1,2,2,1,1,2,2,1,1,0,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0],
            [0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0],
            [0,0,0,0,1,0,1,0,0,1,0,1,0,0,0,0],
            [0,0,0,0,1,0,1,0,0,1,0,1,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
        ]
        let size = 36
        let scale = size / 16
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        for row in 0..<16 {
            for col in 0..<16 {
                if grid[row][col] == 0 { continue }
                let flippedRow = 15 - row
                NSColor.black.setFill()
                NSRect(x: col * scale, y: flippedRow * scale, width: scale, height: scale).fill()
            }
        }
        image.unlockFocus()
        return image
    }

    @objc func toggleVisibility(_ sender: NSMenuItem) {
        guard let crab = controller?.crab else { return }
        if crab.window.isVisible {
            crab.window.orderOut(nil)
            sender.state = .off
            sender.title = "Show Clawd"
        } else {
            crab.window.orderFrontRegardless()
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

    @objc func toggleScreenContext(_ sender: NSMenuItem) {
        if !ScreenContext.enabled && !ScreenContext.hasPermission {
            ScreenContext.requestPermission()
        }
        ScreenContext.enabled.toggle()
        sender.state = ScreenContext.enabled ? .on : .off
    }

    @objc func openChat() {
        togglePopover()
    }

    @objc func newChat() {
        controller?.crab.clearConversation()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
