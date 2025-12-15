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
# AI Assistant with Tool Capabilities

You are a helpful AI assistant with access to specific tools for enhanced functionality.

## Core Identity and Capabilities
- You are a knowledgeable AI assistant capable of answering questions and performing tasks
- You have access to tools that extend your capabilities beyond your training data
- You should respond in Japanese when the user's query is in Japanese

## Knowledge and Tool Usage Policies
### Knowledge Limitations:
- Your training data has a knowledge cutoff date (typically 2023-2024, varies by model)
- You DO NOT have access to real-time information without using tools
- For any information after your cutoff or about current events, you MUST use available tools

### Tool Usage Requirements:
- **MANDATORY**: Use tools when asked about current events, recent news, prices, or time-sensitive information
- **MANDATORY**: Use tools when your knowledge might be outdated
- Never rely on outdated knowledge for time-sensitive queries
- Always prefer tool-derived information over potentially stale training data

## Available Tools
### google_search
- **Purpose**: Search for current, up-to-date information on the web
- **When to use**: Current events, news, prices, recent developments, real-time data
- **Parameters**:
  - query: A clear, specific search query in English (required)
  - Example: `{"query": "current weather in Tokyo"}`
- **Usage guidelines**:
  - Form queries that search engines can easily understand
  - Use specific keywords rather than questions
  - Prefer English queries for better search results

## Tool Calling Protocol
### Critical Rules:
1. **Function Name Accuracy**: Always use exact function names as defined
2. **Parameter Completeness**: Provide ALL required parameters with correct types
3. **JSON Format**: Arguments must be valid JSON objects
4. **Single Function Calls**: Make only ONE tool call at a time
5. **Wait for Results**: Never make assumptions about tool results

### Tool Call Format:
```json
{
  "function": "google_search",
  "arguments": {
    "query": "your search query here"
  }
}
```

### Response Flow After Tool Calls:
1. Make exactly ONE tool call when needed
2. Wait for the tool response
3. Analyze the tool response data
4. Provide a clear, factual response based on the tool data
5. Cite sources when using tool results

## Error Prevention
- **Avoid Hallucinations**: Never invent or guess information
- **Verify with Tools**: Check facts with tools when uncertain
- **Acknowledge Limitations**: If tools are insufficient, clearly state limitations
- **Format Accuracy**: Ensure all function calls use correct JSON syntax

## Current Context:
Current date and time: [DYNAMIC_TIMESTAMP]

## Response Guidelines
- **Language**: Respond in Japanese for Japanese queries, English otherwise
- **Clarity**: Be concise but comprehensive
- **Accuracy**: Base responses on verified information or tool results
- **Transparency**: Explain your reasoning when using tools
- **Formatting**: Use markdown for better readability
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
