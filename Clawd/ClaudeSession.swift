import Foundation

struct ChatMessage {
    enum Role { case user, assistant, error, toolUse, toolResult }
    let role: Role
    let text: String
}

class ClaudeSession: AgentSession {
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var lineBuffer = ""
    private(set) var isRunning = false
    private(set) var isBusy = false
    private static var binaryPath: String?
    private var lastAssistantText = ""

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, [String: Any]) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onSessionReady: (() -> Void)?
    var onTurnComplete: (() -> Void)?
    var onProcessExit: (() -> Void)?
    var history: [ChatMessage] = []

    func start() {
        if let cached = Self.binaryPath {
            launchProcess(binaryPath: cached)
            return
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        ShellEnvironment.findBinary(name: "claude", fallbackPaths: [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]) { [weak self] path in
            guard let self = self, let binaryPath = path else {
                self?.onError?("Claude CLI not found. Install it with: npm install -g @anthropic-ai/claude-code")
                return
            }
            Self.binaryPath = binaryPath
            self.launchProcess(binaryPath: binaryPath)
        }
    }

    private func launchProcess(binaryPath: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--append-system-prompt",
            "You are Clawd, a helpful desktop crab assistant. Be concise and friendly. When screen context is provided, use it to answer questions about what the user sees."
        ]
        proc.currentDirectoryURL = CrabCharacter.workspaceDir
        proc.environment = ShellEnvironment.processEnvironment()

        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.isBusy = false
                self?.onProcessExit?()
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.processOutput(text) }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.onError?(text) }
        }

        do {
            try proc.run()
            process = proc
            inputPipe = inPipe
            outputPipe = outPipe
            errorPipe = errPipe
            isRunning = true
        } catch {
            onError?("Failed to launch Claude: \(error.localizedDescription)")
        }
    }

    func send(message: String, screenshotBase64: String? = nil) {
        guard isRunning, let pipe = inputPipe else { return }
        isBusy = true
        history.append(ChatMessage(role: .user, text: message))

        var content: Any
        if let img = screenshotBase64 {
            content = [
                ["type": "image", "source": ["type": "base64", "media_type": "image/png", "data": img]],
                ["type": "text", "text": message],
            ]
        } else {
            content = message
        }

        let payload: [String: Any] = [
            "type": "user",
            "message": ["role": "user", "content": content]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        pipe.fileHandleForWriting.write((json + "\n").data(using: .utf8)!)
    }

    func terminate() {
        process?.terminate()
        isRunning = false
    }

    private func processOutput(_ text: String) {
        lineBuffer += text
        while let range = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<range.lowerBound])
            lineBuffer = String(lineBuffer[range.upperBound...])
            if !line.isEmpty { parseLine(line) }
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        switch json["type"] as? String ?? "" {
        case "system":
            if json["subtype"] as? String == "init" { onSessionReady?() }

        case "assistant":
            if let msg = json["message"] as? [String: Any],
               let content = msg["content"] as? [[String: Any]] {
                var fullText = ""
                for block in content {
                    let btype = block["type"] as? String ?? ""
                    if btype == "text", let t = block["text"] as? String {
                        fullText += t
                    } else if btype == "tool_use" {
                        let name = block["name"] as? String ?? "Tool"
                        let input = block["input"] as? [String: Any] ?? [:]
                        history.append(ChatMessage(role: .toolUse, text: name))
                        onToolUse?(name, input)
                    }
                }
                if fullText != lastAssistantText {
                    let delta = String(fullText.dropFirst(lastAssistantText.count))
                    lastAssistantText = fullText
                    if !delta.isEmpty {
                        onText?(delta)
                    }
                }
            }

        case "user":
            if let msg = json["message"] as? [String: Any],
               let content = msg["content"] as? [[String: Any]] {
                for block in content where block["type"] as? String == "tool_result" {
                    let isError = block["is_error"] as? Bool ?? false
                    let summary = (block["content"] as? String).map { String($0.prefix(80)) } ?? ""
                    history.append(ChatMessage(role: .toolResult, text: summary))
                    onToolResult?(summary, isError)
                }
            }

        case "result":
            isBusy = false
            if let result = json["result"] as? String, !result.isEmpty {
                history.append(ChatMessage(role: .assistant, text: result))
            }
            lastAssistantText = ""
            onTurnComplete?()

        default: break
        }
    }
}
