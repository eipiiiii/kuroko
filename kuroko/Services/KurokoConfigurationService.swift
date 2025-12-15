import Foundation
import SwiftUI

/// Manages all user-configurable settings for the Kuroko application.
/// This service acts as a centralized configuration manager for API keys, model selection, and prompts.
@Observable
public class KurokoConfigurationService {
    // MARK: - Singleton
    public static let shared = KurokoConfigurationService()

    // MARK: - API Keys
    public var openRouterApiKey: String = ""
    public var googleSearchApiKey: String = ""
    public var googleSearchEngineId: String = ""

    // MARK: - Model Configuration
    public var availableModels: [LLMModel] = []
    public var isFetchingModels = false
    
    /// The ID of the currently selected model. Stored in UserDefaults.
    public var selectedModelId: String = "openai/gpt-4o-mini" // Default model

    /// The currently selected LLMModel object.
    public var selectedModel: LLMModel {
        availableModels.first { $0.modelName == selectedModelId } ?? LLMModel(modelName: selectedModelId, provider: .openRouter, displayName: selectedModelId)
    }

    // MARK: - Prompts
    public var customPrompt: String = ""
    
    // MARK: - Private Properties
    private let openRouterAPIService = OpenRouterAPIService()
    private let modelsCacheKey = "openRouterModelsCache"
    
    // MARK: - Fixed System Instructions
    public static let FIXED_SYSTEM_PROMPT = """
# AI Assistant with Tool Capabilities
You are a helpful AI assistant with access to specific tools for enhanced functionality.
... (rest of the prompt is unchanged) ...
"""

    // MARK: - Initialization
    private init() {
        loadConfiguration()
        loadModelsFromCache()
    }

    // MARK: - Model Fetching and Caching
    @MainActor
    public func fetchOpenRouterModels() async {
        guard !openRouterApiKey.isEmpty, !isFetchingModels else { return }
        
        isFetchingModels = true
        defer { isFetchingModels = false }
        
        do {
            let apiModels = try await openRouterAPIService.fetchModels(apiKey: openRouterApiKey)
            self.availableModels = apiModels.map { LLMModel(from: $0) }
            saveModelsToCache()
            
            // If the currently selected model doesn't exist in the new list, select the first one.
            if !availableModels.contains(where: { $0.modelName == selectedModelId }) {
                selectedModelId = availableModels.first?.modelName ?? ""
            }
            
        } catch {
            print("Failed to fetch OpenRouter models: \(error)")
            // Optionally, present an error to the user
        }
    }
    
    private func saveModelsToCache() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(availableModels) {
            UserDefaults.standard.set(encoded, forKey: modelsCacheKey)
        }
    }

    private func loadModelsFromCache() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: modelsCacheKey),
           let decodedModels = try? decoder.decode([LLMModel].self, from: data) {
            self.availableModels = decodedModels
        }
    }

    // MARK: - Configuration Management

    /// Load all configuration from UserDefaults.
    public func loadConfiguration() {
        openRouterApiKey = UserDefaults.standard.string(forKey: "openRouterApiKey") ?? ""
        selectedModelId = UserDefaults.standard.string(forKey: "selectedModelId") ?? "openai/gpt-4o-mini"
        customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? ""
        googleSearchApiKey = UserDefaults.standard.string(forKey: "googleSearchApiKey") ?? ""
        googleSearchEngineId = UserDefaults.standard.string(forKey: "googleSearchEngineId") ?? ""
    }
    
    /// Save all configuration to UserDefaults.
    public func saveConfiguration() {
        UserDefaults.standard.set(openRouterApiKey, forKey: "openRouterApiKey")
        UserDefaults.standard.set(selectedModelId, forKey: "selectedModelId")
        UserDefaults.standard.set(customPrompt, forKey: "customPrompt")
        UserDefaults.standard.set(googleSearchApiKey, forKey: "googleSearchApiKey")
        UserDefaults.standard.set(googleSearchEngineId, forKey: "googleSearchEngineId")
    }

    /// Get the combined system prompt (fixed + custom).
    public func getCombinedPrompt() -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let promptWithTimestamp = Self.FIXED_SYSTEM_PROMPT.replacingOccurrences(of: "[DYNAMIC_TIMESTAMP]", with: timestamp)

        if customPrompt.isEmpty {
            return promptWithTimestamp
        } else {
            return promptWithTimestamp + "\n\n## Custom Instructions:\n" + customPrompt
        }
    }
}
