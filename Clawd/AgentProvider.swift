import Foundation

enum AgentProvider: String, CaseIterable {
    case claude, codex

    private static let defaultsKey = "selectedProvider"

    static var current: AgentProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? "claude"
            return AgentProvider(rawValue: raw) ?? .claude
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex:  return "Codex"
        }
    }

    var installInstructions: String {
        switch self {
        case .claude:
            return "Install: curl -fsSL https://claude.ai/install.sh | sh"
        case .codex:
            return "Install: npm install -g @openai/codex"
        }
    }

    func createSession() -> AgentSession {
        switch self {
        case .claude: return ClaudeSession()
        case .codex:  return CodexSession()
        }
    }
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
