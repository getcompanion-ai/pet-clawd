import XCTest
@testable import Clawd

final class ChatMessageTests: XCTestCase {

    func testUserMessageCreation() {
        let msg = ChatMessage(role: .user, text: "Hello")
        XCTAssertTrue(msg.role == .user)
        XCTAssertEqual(msg.text, "Hello")
    }

    func testAssistantMessageCreation() {
        let msg = ChatMessage(role: .assistant, text: "Hi there")
        XCTAssertTrue(msg.role == .assistant)
        XCTAssertEqual(msg.text, "Hi there")
    }

    func testAllRolesExist() {
        let roles: [ChatMessage.Role] = [.user, .assistant, .error, .toolUse, .toolResult]
        XCTAssertEqual(roles.count, 5)
    }
}
