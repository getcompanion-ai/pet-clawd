import Foundation

func createAgentSession() -> AgentSession {
    return ClaudeSession()
}

protocol AgentSession: AnyObject {
    var isRunning: Bool { get }
    var isBusy: Bool { get }
    var history: [ChatMessage] { get set }

    var onText: ((String) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var onToolUse: ((String, [String: Any]) -> Void)? { get set }
    var onToolResult: ((String, Bool) -> Void)? { get set }
    var onSessionReady: (() -> Void)? { get set }
    var onTurnComplete: (() -> Void)? { get set }
    var onProcessExit: (() -> Void)? { get set }

    func start()
    func send(message: String, screenshotBase64: String?)
    func terminate()
}
