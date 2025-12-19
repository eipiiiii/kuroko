import Foundation

// MARK: - Core Message and Tooling Models

/// Represents the role of a message sender in a chat conversation.
public enum MessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
    case toolProposal
    case toolResult
}

/// Represents a single message in a chat conversation.
public struct ChatMessage: Identifiable, Equatable {
    public let id = UUID()
    public let role: MessageRole
    public var text: String
    public var isStreaming: Bool = false
    public var toolCallId: String? = nil
    public var toolCalls: [ToolCall]? = nil
}

/// Represents a function call requested by the model.
public struct FunctionCall: Codable, Equatable {
    public let name: String
    public let arguments: String
}

/// Represents a tool call request from the model.
public struct ToolCall: Codable, Equatable {
    public let id: String
    public let type: String
    public let function: FunctionCall
}

// MARK: - Model and Configuration Structures

/// Represents a specific LLM available through a provider.
public struct LLMModel: Identifiable, Hashable, Codable {
    public let id = UUID()
    public let modelName: String // e.g., "openai/gpt-4o-mini"
    public let provider: LLMProvider
    public let displayName: String // e.g., "GPT-4o mini"

    // Custom Codable implementation to ignore 'id' during encoding/decoding
    enum CodingKeys: String, CodingKey {
        case modelName, provider, displayName
    }

    public init(modelName: String, provider: LLMProvider, displayName: String) {
        self.modelName = modelName
        self.provider = provider
        self.displayName = displayName
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modelName = try container.decode(String.self, forKey: .modelName)
        provider = try container.decode(LLMProvider.self, forKey: .provider)
        displayName = try container.decode(String.self, forKey: .displayName)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(provider, forKey: .provider)
        try container.encode(displayName, forKey: .displayName)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(modelName)
        hasher.combine(provider)
    }

    public static func == (lhs: LLMModel, rhs: LLMModel) -> Bool {
        return lhs.modelName == rhs.modelName && lhs.provider == rhs.provider
    }
}

public extension LLMModel {
    /// Creates an `LLMModel` from an `OpenRouterAPIModel`.
    init(from apiModel: OpenRouterAPIModel) {
        self.init(
            modelName: apiModel.id,
            provider: .openRouter,
            displayName: apiModel.name
        )
    }
}

/// Configuration for making a request to an LLM.
public struct LLMConfig {
    public let model: LLMModel
    public let temperature: Double = 0.8
    // Other parameters like topP, etc., can be added here.
}
