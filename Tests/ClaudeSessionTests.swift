import XCTest
@testable import Clawd

final class ClaudeSessionTests: XCTestCase {

    // MARK: - NDJSON Parsing

    func testSystemInitFiresSessionReady() {
        let session = ClaudeSession()
        var ready = false
        session.onSessionReady = { ready = true }

        session.processOutput("{\"type\":\"system\",\"subtype\":\"init\"}\n")
        XCTAssertTrue(ready)
    }

    func testSystemInitFlushesPendingMessages() {
        let session = ClaudeSession()
        session.isRunning = false

        session.send(message: "hello")
        session.send(message: "world")

        XCTAssertEqual(session.history.count, 0, "Messages should be queued, not sent")

        session.isRunning = true

        var readyFired = false
        session.onSessionReady = { readyFired = true }
        session.processOutput("{\"type\":\"system\",\"subtype\":\"init\"}\n")

        XCTAssertTrue(readyFired)
    }

    func testAssistantTextStreaming() {
        let session = ClaudeSession()
        var received = ""
        session.onText = { delta in received += delta }

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Hello\"}]}}\n")
        XCTAssertEqual(received, "Hello")

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Hello world\"}]}}\n")
        XCTAssertEqual(received, "Hello world")
    }

    func testAssistantDeltaCalculation() {
        let session = ClaudeSession()
        var deltas: [String] = []
        session.onText = { delta in deltas.append(delta) }

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Hi\"}]}}\n")
        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Hi there\"}]}}\n")
        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Hi there!\"}]}}\n")

        XCTAssertEqual(deltas, ["Hi", " there", "!"])
    }

    func testResultCommitsStreamedTextToHistory() {
        let session = ClaudeSession()
        session.onText = { _ in }

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Hello world\"}]}}\n")
        XCTAssertEqual(session.history.count, 0, "History should not have assistant entry yet")

        session.processOutput("{\"type\":\"result\",\"result\":\"\"}\n")
        XCTAssertEqual(session.history.count, 1)
        XCTAssertEqual(session.history[0].text, "Hello world")
        XCTAssertTrue(session.history[0].role == .assistant)
    }

    func testResultWithEmptyStreamUsesResultField() {
        let session = ClaudeSession()
        session.onText = { _ in }

        session.processOutput("{\"type\":\"result\",\"result\":\"Final answer\"}\n")
        XCTAssertEqual(session.history.count, 1)
        XCTAssertEqual(session.history[0].text, "Final answer")
    }

    func testResultWithEmptyStreamAlsoEmitsTextCallback() {
        let session = ClaudeSession()
        var received = ""
        session.onText = { delta in received += delta }

        session.processOutput("{\"type\":\"result\",\"result\":\"Final answer\"}\n")

        XCTAssertEqual(received, "Final answer")
    }

    func testResultPrefersStreamedTextOverResultField() {
        let session = ClaudeSession()
        session.onText = { _ in }

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Streamed\"}]}}\n")
        session.processOutput("{\"type\":\"result\",\"result\":\"Result field\"}\n")

        XCTAssertEqual(session.history.count, 1)
        XCTAssertEqual(session.history[0].text, "Streamed")
    }

    func testResultResetsBusyFlag() {
        let session = ClaudeSession()
        session.isBusy = true

        session.processOutput("{\"type\":\"result\",\"result\":\"\"}\n")
        XCTAssertFalse(session.isBusy)
    }

    func testTurnCompleteFiresOnResult() {
        let session = ClaudeSession()
        var completed = false
        session.onTurnComplete = { completed = true }

        session.processOutput("{\"type\":\"result\",\"result\":\"\"}\n")
        XCTAssertTrue(completed)
    }

    func testToolUseDetected() {
        let session = ClaudeSession()
        var toolName: String?
        var toolInput: [String: Any]?
        session.onToolUse = { name, input in
            toolName = name
            toolInput = input
        }

        let json = "{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"ls -la\"}}]}}"
        session.processOutput(json + "\n")

        XCTAssertEqual(toolName, "Bash")
        XCTAssertEqual(toolInput?["command"] as? String, "ls -la")
    }

    func testToolUseAppendsToHistory() {
        let session = ClaudeSession()
        session.onToolUse = { _, _ in }

        let json = "{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{\"file_path\":\"/tmp/test.txt\"}}]}}"
        session.processOutput(json + "\n")

        XCTAssertEqual(session.history.count, 1)
        XCTAssertEqual(session.history[0].text, "Read: /tmp/test.txt")
        XCTAssertTrue(session.history[0].role == .toolUse)
    }

    func testToolResultDetected() {
        let session = ClaudeSession()
        var resultSummary: String?
        var resultIsError: Bool?
        session.onToolResult = { summary, isError in
            resultSummary = summary
            resultIsError = isError
        }

        let json = "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"content\":\"file contents here\",\"is_error\":false}]}}"
        session.processOutput(json + "\n")

        XCTAssertEqual(resultSummary, "file contents here")
        XCTAssertEqual(resultIsError, false)
    }

    func testToolResultError() {
        let session = ClaudeSession()
        var resultIsError: Bool?
        session.onToolResult = { _, isError in resultIsError = isError }

        let json = "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"tool_result\",\"content\":\"command failed\",\"is_error\":true}]}}"
        session.processOutput(json + "\n")

        XCTAssertEqual(resultIsError, true)
    }

    // MARK: - Line buffer

    func testPartialLinesBuffered() {
        let session = ClaudeSession()
        var received = ""
        session.onText = { delta in received += delta }

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",")
        XCTAssertEqual(received, "", "Partial line should not trigger callback")

        session.processOutput("\"content\":[{\"type\":\"text\",\"text\":\"Hi\"}]}}\n")
        XCTAssertEqual(received, "Hi")
    }

    func testMultipleLinesInOneChunk() {
        let session = ClaudeSession()
        var ready = false
        var text = ""
        session.onSessionReady = { ready = true }
        session.onText = { delta in text += delta }

        let chunk = "{\"type\":\"system\",\"subtype\":\"init\"}\n{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Hi\"}]}}\n"
        session.processOutput(chunk)

        XCTAssertTrue(ready)
        XCTAssertEqual(text, "Hi")
    }

    func testInvalidJsonIgnored() {
        let session = ClaudeSession()
        var errorFired = false
        session.onError = { _ in errorFired = true }

        session.processOutput("not json at all\n")
        session.processOutput("{broken json\n")

        XCTAssertFalse(errorFired, "Invalid JSON should be silently ignored")
    }

    func testUnknownTypeIgnored() {
        let session = ClaudeSession()
        session.processOutput("{\"type\":\"unknown_event\",\"data\":\"something\"}\n")
        XCTAssertEqual(session.history.count, 0)
    }

    // MARK: - Pending message queue

    func testSendQueuesWhenNotRunning() {
        let session = ClaudeSession()
        session.isRunning = false

        session.send(message: "test1")
        session.send(message: "test2")

        XCTAssertEqual(session.history.count, 0)
    }

    // MARK: - Multi-turn reset

    func testLastAssistantTextResetsOnResult() {
        let session = ClaudeSession()
        var deltas: [String] = []
        session.onText = { delta in deltas.append(delta) }

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"First response\"}]}}\n")
        session.processOutput("{\"type\":\"result\",\"result\":\"\"}\n")

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Second\"}]}}\n")

        XCTAssertEqual(deltas, ["First response", "Second"])
    }

    func testCurrentResponseTextResetsOnResult() {
        let session = ClaudeSession()
        session.onText = { _ in }

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Turn 1\"}]}}\n")
        session.processOutput("{\"type\":\"result\",\"result\":\"\"}\n")

        session.processOutput("{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"Turn 2\"}]}}\n")
        session.processOutput("{\"type\":\"result\",\"result\":\"\"}\n")

        XCTAssertEqual(session.history.count, 2)
        XCTAssertEqual(session.history[0].text, "Turn 1")
        XCTAssertEqual(session.history[1].text, "Turn 2")
    }

    // MARK: - formatToolSummary

    func testFormatToolSummaryBash() {
        let result = ClaudeSession.formatToolSummary(name: "Bash", input: ["command": "ls -la /tmp"])
        XCTAssertEqual(result, "Bash: ls -la /tmp")
    }

    func testFormatToolSummaryBashMultiline() {
        let result = ClaudeSession.formatToolSummary(name: "Bash", input: ["command": "echo hello\necho world"])
        XCTAssertEqual(result, "Bash: echo hello")
    }

    func testFormatToolSummaryBashTruncates() {
        let longCmd = String(repeating: "a", count: 100)
        let result = ClaudeSession.formatToolSummary(name: "Bash", input: ["command": longCmd])
        XCTAssertTrue(result.count <= 66)
    }

    func testFormatToolSummaryRead() {
        let result = ClaudeSession.formatToolSummary(name: "Read", input: ["file_path": "/tmp/test.swift"])
        XCTAssertEqual(result, "Read: /tmp/test.swift")
    }

    func testFormatToolSummaryEdit() {
        let result = ClaudeSession.formatToolSummary(name: "Edit", input: ["file_path": "/src/main.swift"])
        XCTAssertEqual(result, "Edit: /src/main.swift")
    }

    func testFormatToolSummaryWrite() {
        let result = ClaudeSession.formatToolSummary(name: "Write", input: ["file_path": "/new.txt"])
        XCTAssertEqual(result, "Write: /new.txt")
    }

    func testFormatToolSummaryGlob() {
        let result = ClaudeSession.formatToolSummary(name: "Glob", input: ["pattern": "**/*.swift"])
        XCTAssertEqual(result, "Glob: **/*.swift")
    }

    func testFormatToolSummaryGrep() {
        let result = ClaudeSession.formatToolSummary(name: "Grep", input: ["pattern": "TODO"])
        XCTAssertEqual(result, "Grep: TODO")
    }

    func testFormatToolSummaryUnknown() {
        let result = ClaudeSession.formatToolSummary(name: "CustomTool", input: [:])
        XCTAssertEqual(result, "CustomTool")
    }

    // MARK: - Model selection

    func testLaunchArgumentsDefaultToSonnet() {
        let arguments = ClaudeSession.launchArguments(environment: [:])

        XCTAssertEqual(arguments[0], "-p")
        XCTAssertEqual(arguments[1], "--model")
        XCTAssertEqual(arguments[2], "sonnet")
    }

    func testResolvedModelUsesEnvironmentOverride() {
        let model = ClaudeSession.resolvedModel(environment: [
            ClaudeSession.modelOverrideEnvironmentKey: "opus"
        ])

        XCTAssertEqual(model, "opus")
    }
}
