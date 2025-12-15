import Foundation

/// A placeholder service that conforms to `LLMService` but does nothing.
/// This is used to prevent the app from crashing if the `LLMServiceFactory`
/// is unable to create a valid service (e.g., due to a misconfiguration).
public class UnsupportedLLMService: LLMService {
    public let provider: LLMProvider = .openRouter // Placeholder, doesn't matter
    
    public init() {}

    /// Always throws an error indicating that the provider is unsupported.
    public func sendMessage(
        message: String,
        history: [ChatMessage],
        config: LLMConfig,
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws {
        throw NSError(
            domain: "Kuroko.UnsupportedLLMService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The configured LLM Provider is not supported or could not be initialized."]
        )
    }
}
