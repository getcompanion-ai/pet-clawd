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
    var isRunning = false
    var isBusy = false
    private static var binaryPath: String?
    private var lastAssistantText = ""
    private var currentResponseText = ""
    private var pendingMessages: [(message: String, screenshot: String?)] = []

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
            "You are a helpful desktop assistant. Be concise and friendly. Keep responses short. When screen context is provided, use it to answer questions. Never mention being a crab, AI, or assistant. Never be meta or self-referential. Just help."
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

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
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
            flushPending()
        }
    }

    func send(message: String, screenshotBase64: String? = nil) {
        if !isRunning || inputPipe == nil || isBusy {
            pendingMessages.append((message: message, screenshot: screenshotBase64))
            return
        }
        guard let pipe = inputPipe else { return }
        isBusy = true
        if !message.hasPrefix("<system>") {
            history.append(ChatMessage(role: .user, text: message))
        }

        var content: Any
        if let img = screenshotBase64 {
            content = [
                ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": img]],
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
        do {
            try pipe.fileHandleForWriting.write(contentsOf: (json + "\n").data(using: .utf8)!)
        } catch {
            onError?("Failed to write to Claude: \(error.localizedDescription)")
        }
    }

    private func flushPending() {
        let queued = pendingMessages
        pendingMessages.removeAll()
        for msg in queued {
            send(message: msg.message, screenshotBase64: msg.screenshot)
        }
    }

    func terminate() {
        process?.terminate()
        isRunning = false
    }

    static func formatToolSummary(name: String, input: [String: Any]) -> String {
        switch name.lowercased() {
        case "bash", "terminal":
            if let cmd = input["command"] as? String {
                let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
                let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
                return "\(name): \(String(firstLine.prefix(60)))"
            }
        case "read":
            if let path = input["file_path"] as? String { return "Read: \(path)" }
        case "edit":
            if let path = input["file_path"] as? String { return "Edit: \(path)" }
        case "write":
            if let path = input["file_path"] as? String { return "Write: \(path)" }
        case "glob":
            if let pattern = input["pattern"] as? String { return "Glob: \(pattern)" }
        case "grep":
            if let pattern = input["pattern"] as? String { return "Grep: \(pattern)" }
        default: break
        }
        return name
    }

    func processOutput(_ text: String) {
        lineBuffer += text
        while let range = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex..<range.lowerBound])
            lineBuffer = String(lineBuffer[range.upperBound...])
            if !line.isEmpty { parseLine(line) }
        }
    }

    func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        switch json["type"] as? String ?? "" {
        case "system":
            if json["subtype"] as? String == "init" {
                onSessionReady?()
                flushPending()
            }

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
                        let summary = Self.formatToolSummary(name: name, input: input)
                        history.append(ChatMessage(role: .toolUse, text: summary))
                        onToolUse?(name, input)
                    }
                }
                if fullText != lastAssistantText {
                    let delta = String(fullText.dropFirst(lastAssistantText.count))
                    lastAssistantText = fullText
                    currentResponseText += delta
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
            if !currentResponseText.isEmpty {
                history.append(ChatMessage(role: .assistant, text: currentResponseText))
            } else if let result = json["result"] as? String, !result.isEmpty {
                currentResponseText = result
                onText?(result)
                history.append(ChatMessage(role: .assistant, text: result))
            }
            lastAssistantText = ""
            currentResponseText = ""
            onTurnComplete?()
            flushPending()

        default: break
        }
    }
}
