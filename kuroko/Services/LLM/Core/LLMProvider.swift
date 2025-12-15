import Foundation

/// Defines the supported LLM providers
public enum LLMProvider: String, CaseIterable, Codable {
    case openRouter = "OpenRouter"
    // Future providers can be added here, e.g.:
    // case openAI = "OpenAI"
    // case anthropic = "Anthropic"
}
