import Foundation

class CodexSession: AgentSession {
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var lineBuffer = ""
    private(set) var isRunning = false
    private(set) var isBusy = false
    private var isFirstTurn = true
    private static var binaryPath: String?

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, [String: Any]) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onSessionReady: (() -> Void)?
    var onTurnComplete: (() -> Void)?
    var onProcessExit: (() -> Void)?
    var history: [ChatMessage] = []

    func start() {
        if Self.binaryPath != nil {
            isRunning = true
            onSessionReady?()
            return
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        ShellEnvironment.findBinary(name: "codex", fallbackPaths: [
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex"
        ]) { [weak self] path in
            guard let self = self, let p = path else {
                self?.onError?("Codex CLI not found.\n\n\(AgentProvider.codex.installInstructions)")
                return
            }
            Self.binaryPath = p
            self.isRunning = true
            self.onSessionReady?()
        }
    }

    func send(message: String, screenshotBase64: String? = nil) {
        guard isRunning, let binaryPath = Self.binaryPath else { return }
        isBusy = true
        history.append(ChatMessage(role: .user, text: message))
        lineBuffer = ""

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = isFirstTurn
            ? ["exec", "--json", "--full-auto", "--skip-git-repo-check", message]
            : ["exec", "resume", "--last", "--json", "--full-auto", "--skip-git-repo-check", message]
        proc.currentDirectoryURL = CrabCharacter.workspaceDir
        proc.environment = ShellEnvironment.processEnvironment()

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.process = nil
                if !self.lineBuffer.isEmpty {
                    self.parseLine(self.lineBuffer)
                    self.lineBuffer = ""
                }
                if self.isBusy {
                    self.isBusy = false
                    self.onTurnComplete?()
                }
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
            outputPipe = outPipe
            errorPipe = errPipe
            isFirstTurn = false
        } catch {
            isBusy = false
            onError?("Failed to launch Codex: \(error.localizedDescription)")
        }
    }

    func terminate() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        isRunning = false
        isBusy = false
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
        case "item.started":
            if let item = json["item"] as? [String: Any],
               item["type"] as? String == "command_execution" {
                let cmd = item["command"] as? String ?? ""
                history.append(ChatMessage(role: .toolUse, text: "Bash: \(cmd)"))
                onToolUse?("Bash", ["command": cmd])
            }

        case "item.completed":
            if let item = json["item"] as? [String: Any] {
                switch item["type"] as? String ?? "" {
                case "agent_message":
                    let text = item["text"] as? String ?? ""
                    if !text.isEmpty {
                        history.append(ChatMessage(role: .assistant, text: text))
                        onText?(text)
                    }
                case "command_execution":
                    let status = item["status"] as? String ?? ""
                    let cmd = item["command"] as? String ?? ""
                    let isError = status == "failed"
                    let summary = cmd.isEmpty ? status : String(cmd.prefix(80))
                    history.append(ChatMessage(role: .toolResult, text: isError ? "ERROR: \(summary)" : summary))
                    onToolResult?(summary, isError)
                case "file_change":
                    let path = item["file"] as? String ?? item["path"] as? String ?? "file"
                    history.append(ChatMessage(role: .toolUse, text: "FileChange: \(path)"))
                    onToolUse?("FileChange", ["file_path": path])
                    onToolResult?(path, false)
                default: break
                }
            }

        case "turn.completed":
            isBusy = false
            onTurnComplete?()

        case "turn.failed":
            isBusy = false
            let msg = json["message"] as? String ?? "Turn failed"
            onError?(msg)
            onTurnComplete?()

        case "error":
            let msg = json["message"] as? String ?? "Unknown error"
            onError?(msg)

        default: break
        }
    }
}
