import Foundation

// MARK: - Session Models

struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [SessionMessage]
    
    init(id: UUID = UUID(), title: String = "新しい会話", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [SessionMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

struct SessionMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: String // "user" or "model"
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}
