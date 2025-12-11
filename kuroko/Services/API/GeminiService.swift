import Foundation
import GoogleGenerativeAI

// MARK: - Gemini Service Protocol

protocol GeminiServiceProtocol {
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws
    
    func updateModelConfiguration()
}

// MARK: - Gemini Service

/// Handles all Gemini API interactions
class GeminiService: GeminiServiceProtocol {
    private let configService: APIConfigurationService
    private var model: GenerativeModel?
    
    init(configService: APIConfigurationService = .shared) {
        self.configService = configService
        updateModelConfiguration()
    }
    
    /// Update the Gemini model configuration
    func updateModelConfiguration() {
        guard configService.hasValidApiKey() else {
            model = nil
            return
        }
        
        let combinedPrompt = configService.getCombinedPrompt()
        
        let generationConfig = GenerationConfig(temperature: 0.8)
        
        if !combinedPrompt.isEmpty {
            model = GenerativeModel(
                name: configService.selectedModel,
                apiKey: configService.geminiApiKey,
                generationConfig: generationConfig,
                systemInstruction: ModelContent(parts: [.text(combinedPrompt)])
            )
        } else {
            model = GenerativeModel(
                name: configService.selectedModel,
                apiKey: configService.geminiApiKey,
                generationConfig: generationConfig
            )
        }
    }
    
    /// Send a message and stream the response
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws {
        guard let model = model else {
            throw GeminiServiceError.modelNotConfigured
        }
        
        // Convert history to Gemini format
        let geminiHistory = history.compactMap { chatMessage -> ModelContent? in
            // Messages with empty text are not allowed
            if chatMessage.text.isEmpty, chatMessage.toolCalls == nil {
                return nil
            }
            
            var parts: [ModelContent.Part] = []
            
            parts.append(.text(chatMessage.text))
            
            return ModelContent(
                role: chatMessage.role.rawValue,
                parts: parts
            )
        }
        
        let chat = model.startChat(history: geminiHistory)
        let responseStream = chat.sendMessageStream(message)
        
        for try await chunk in responseStream {
            if let text = chunk.text {
                onChunk(text)
            }
        }
    }
}

// MARK: - Errors

enum GeminiServiceError: LocalizedError {
    case modelNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .modelNotConfigured:
            return "Gemini model is not configured. Please check your API key."
        }
    }
}
