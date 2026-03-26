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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = ClawdController()
        controller?.start()
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.crab.session?.terminate()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "fossil.shell.fill", accessibilityDescription: "Clawd")
                ?? NSImage(systemSymbolName: "ladybug.fill", accessibilityDescription: "Clawd")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Show Clawd", action: #selector(toggleVisibility(_:)), keyEquivalent: "c")
        toggleItem.state = .on
        menu.addItem(toggleItem)

        let newChatItem = NSMenuItem(title: "New Chat", action: #selector(newChat), keyEquivalent: "n")
        menu.addItem(newChatItem)

        menu.addItem(NSMenuItem.separator())

        let screenItem = NSMenuItem(title: "Screen Context", action: #selector(toggleScreenContext(_:)), keyEquivalent: "")
        screenItem.state = .on
        menu.addItem(screenItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
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

    @objc func toggleScreenContext(_ sender: NSMenuItem) {
        ScreenContext.enabled.toggle()
        sender.state = ScreenContext.enabled ? .on : .off
    }

    @objc func newChat() {
        guard let crab = controller?.crab else { return }
        crab.session?.terminate()
        crab.session = nil
        crab.responseText = ""
        crab.isStreaming = false
        crab.stopDots()
        crab.panelHistory?.textStorage?.setAttributedString(NSAttributedString(string: ""))
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
