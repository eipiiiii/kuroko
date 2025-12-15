import Foundation

/// Defines the contract for a service that interacts with a Large Language Model.
public protocol LLMService {
    /// The provider this service implementation represents.
    var provider: LLMProvider { get }

    /// Sends a message to the LLM and receives a streaming response.
    ///
    /// - Parameters:
    ///   - message: The user's message to send.
    ///   - history: An array of previous chat messages for context.
    ///   - config: The configuration for the LLM call (e.g., model, parameters).
    ///   - onChunk: A callback that receives chunks of the response text as they arrive.
    ///   - onToolCall: A callback that is triggered when the model requests a tool to be called.
    func sendMessage(
        message: String,
        history: [ChatMessage],
        config: LLMConfig,
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws
}
