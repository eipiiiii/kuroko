import Foundation

// MARK: - Message Models

enum MessageRole: String, Codable {
    case user
    case model
    case tool // New role for tool outputs
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var text: String
    var isStreaming: Bool = false
    var toolCallId: String? = nil // For identifying tool responses
    var toolCalls: [ToolCall]? = nil // For storing tool calls made by the model
}
