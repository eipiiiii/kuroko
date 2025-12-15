import Foundation

// MARK: - API Configuration Service

/// Manages API keys, model selection, and prompt configuration
/// This service acts as a centralized configuration manager for all API-related settings
@Observable
class APIConfigurationService {
    // MARK: - Singleton
    static let shared = APIConfigurationService()
    
    // MARK: - API Keys
    var openRouterApiKey: String = ""
    var googleSearchApiKey: String = ""
    var googleSearchEngineId: String = ""
    
    // MARK: - Model Configuration
    var selectedProvider: String = "openrouter"
    var selectedModel: String = "openai/gpt-4o-mini"
    
    // MARK: - Prompts
    var customPrompt: String = ""
    
    // MARK: - Fixed System Instructions (Read-only)
    static let FIXED_SYSTEM_PROMPT = """
You are a helpful AI assistant with access to web search capabilities.

## Your Knowledge Limitations:
- Your training data has a knowledge cutoff date (typically 2023-2024, varies by model).
- You DO NOT have access to real-time information without using tools.
- For any information after your cutoff or about current events, you MUST use the google_search tool.
- Never guess or hallucinate current information - always search when uncertain.

## Current Context:
Current date and time: [DYNAMIC_TIMESTAMP]

## Tool Usage Guidelines:
- When you need up-to-date information (e.g., current prices, latest news, recent events), use the `google_search` tool.
- When the user asks about information that may have changed since your knowledge cutoff, use the search tool.
- Always cite sources when using search results.
- If search results are insufficient, acknowledge the limitation.

## Response Style:
- Be concise and clear.
- Use markdown formatting for better readability.
- Provide accurate information based on your knowledge or search results.
"""
    
    // MARK: - Initialization
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Management
    
    /// Load all configuration from UserDefaults
    func loadConfiguration() {
        openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "openai/gpt-4o-mini"
        selectedProvider = UserDefaults.standard.string(forKey: "selectedProvider") ?? "openrouter"
        customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? ""
        googleSearchApiKey = UserDefaults.standard.string(forKey: "googleSearchApiKey") ?? ""
        googleSearchEngineId = UserDefaults.standard.string(forKey: "googleSearchEngineId") ?? ""
    }
    
    /// Get the combined system prompt (fixed + custom)
    func getCombinedPrompt() -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let promptWithTimestamp = Self.FIXED_SYSTEM_PROMPT.replacingOccurrences(of: "[DYNAMIC_TIMESTAMP]", with: timestamp)
        
        if customPrompt.isEmpty {
            return promptWithTimestamp
        } else {
            return promptWithTimestamp + "\n\n## Custom Instructions:\n" + customPrompt
        }
    }
    
    /// Check if the current provider has a valid API key
    func hasValidApiKey() -> Bool {
        // Only OpenRouter is supported
        return !openRouterApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Get error message for missing API key
    func getApiKeyErrorMessage() -> String {
        return "OpenRouter APIキーを設定してください"
    }
}
