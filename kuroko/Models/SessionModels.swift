import Foundation

// MARK: - Session Models

public struct ChatSession: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var messages: [SessionMessage]
    
    public init(id: UUID = UUID(), title: String = "新しい会話", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [SessionMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

public struct SessionMessage: Identifiable, Codable, Equatable {
    public let id: UUID
    public let role: String // "user", "model", or "tool"
    public let text: String
    public let timestamp: Date
    
    public init(id: UUID = UUID(), role: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
    
    /// Convenience initializer to create a `SessionMessage` from a `ChatMessage`.
    public init(from chatMessage: ChatMessage) {
        self.init(
            role: chatMessage.role.rawValue,
            text: chatMessage.text
        )
    }
}

// Convenience initializer to create a `ChatMessage` from a `SessionMessage`
public extension ChatMessage {
    init(from sessionMessage: SessionMessage) {
        self.init(
            role: MessageRole(rawValue: sessionMessage.role) ?? .assistant,
            text: sessionMessage.text,
            isStreaming: false
            // Note: Tool call information is not stored in SessionMessage in this design
        )
    }
}
