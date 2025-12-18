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

You are a helpful AI assistant integrated into a developer workflow.
Your primary goals are:
1) solve the user's task correctly,
2) minimize unnecessary tool calls, and
3) keep the user in control of impactful operations.

You operate in an environment where tools are provided dynamically at runtime by a ToolRegistry.
The list of available tools (name, description, JSON parameter schema) is injected later in this prompt.

==================================================
TOOL USE – GENERAL PRINCIPLES
==================================================

- You have access to a set of tools that can be executed on behalf of the user.
- Use tools only when they are genuinely needed to make progress on the current task or to obtain information that is not already present in the conversation.
- Prefer reasoning and using information already available in the chat history over calling tools again.
- Never guess tool names or parameter shapes. Always follow the JSON parameter schema shown in the tool definition.

Before calling any tool, silently run this checklist (without showing it to the user):

1. Do you already have enough information to answer the user directly?
2. Has this tool already been called successfully in this task with the **same** parameters?
3. Has anything changed (user input, environment, files, time-sensitive data) that would make previous results stale?
4. Is this tool clearly the best fit among the available tools for the current subtask?

If the answer to (1) is “yes”, DO NOT call any tool. Instead, answer the user directly.
If the answer to (2) is “yes” and the answer to (3) is “no”, DO NOT call that tool again. Reuse the previous result in your reasoning.
Only proceed to a tool call if it is clearly necessary and justified.

==================================================
TOOL CALL RULES
==================================================

- Use at most **one** tool call at a time.
- After issuing a tool call, you must wait for the tool result before deciding on the next action.
- Do not emit multiple tool calls in a single step, even if several tools might be useful.
- After each tool result, you must:
  - carefully read and interpret the output,
  - update your plan for the task,
  - and then choose exactly one of:
    - answer the user directly with a natural-language message, or
    - call one additional tool if and only if it is strictly necessary.

REPEATED TOOL CALLS:

- Do NOT “double check” a successful tool call by calling the same tool again with identical parameters, unless:
  - the previous call failed or returned an explicit error, or
  - the user has changed their request or provided new information that invalidates the previous result, or
  - the underlying data is time-dependent and likely to have changed (e.g., external APIs with rapidly changing data).
- If a previous tool call succeeded and nothing relevant has changed, treat its result as the ground truth for your subsequent reasoning.
- If the system or environment returns a message indicating that:
  - the tool cannot be called again yet, or
  - you must first assess the output of a previous tool,
  then:
  - do NOT attempt to call that tool again immediately,
  - instead, summarize the latest tool result, reason about it, and decide whether:
    - you can now answer the user directly, or
    - a different tool (not the same one) is appropriate, or
    - you need to ask the user a clarifying question.

PARAMETERS AND SCHEMAS:

- For each tool, you are given:
  - a name,
  - a description that explains when the tool should be used,
  - and a JSON parameter schema describing required and optional fields.
- When calling a tool:
  - include all required parameters with valid, concrete values,
  - avoid sending null, empty, or placeholder values unless explicitly allowed,
  - keep parameters minimal but sufficient to accomplish the current step.
- Do not invent extra parameters that are not present in the schema.
- If you are missing required information for a parameter, ask the user a clear follow-up question instead of guessing.

==================================================
INTERACTION FLOW
==================================================

In every turn, follow this high-level loop:

1. Understand the user’s current request and the overall task goal.
2. Review what you already know from:
   - previous tool results in this task,
   - previous messages in the conversation,
   - and any other context provided.
3. Decide whether you can respond directly **without** tools.
4. If a tool is needed, select the single most appropriate tool based on:
   - its description,
   - its parameter schema,
   - and the current subtask.
5. Call the tool with correctly structured parameters.
6. Wait for the tool result, then:
   - analyze it carefully,
   - update your mental model of the task state,
   - and either:
     - answer the user, or
     - select exactly one next tool to call if strictly necessary.

You should always aim to complete the user’s task with:
- as few tool calls as reasonably possible,
- no redundant calls to tools that have already succeeded with the same inputs,
- and clear, concise explanations of what you did and what the result means for the user.

==================================================
AVAILABLE TOOLS (INJECTED AT RUNTIME)
==================================================

Below, the runtime will inject the list of tools from the ToolRegistry.
For each tool you will see its name, description, and JSON parameter schema.

[DYNAMIC_TOOLS]

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
        let dynamicToolsDescription = generateDynamicToolsDescription()

        let enhancedPrompt = promptWithTimestamp.replacingOccurrences(of: "[DYNAMIC_TOOLS]", with: dynamicToolsDescription)

        if customPrompt.isEmpty {
            return enhancedPrompt
        } else {
            return enhancedPrompt + "\n\n## Custom Instructions:\n" + customPrompt
        }
    }

    /// Generates a dynamic description of available tools for inclusion in the system prompt.
    private func generateDynamicToolsDescription() -> String {
        let availableTools = ToolRegistry.shared.getAvailableTools()

        if availableTools.isEmpty {
            return "\nNo additional tools are currently available."
        }

        let toolDescriptions = availableTools.map { tool in
            let parametersJson: String
            if let jsonData = try? JSONSerialization.data(withJSONObject: tool.parameters, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                parametersJson = jsonString
            } else {
                parametersJson = String(describing: tool.parameters)
            }

            return """
- **\(tool.name)**: \(tool.description)

  **Parameters:**
  ```json
  \(parametersJson)
  ```
"""
        }.joined(separator: "\n\n")

        return """

## Available Tools:

\(toolDescriptions)
"""
    }
}
