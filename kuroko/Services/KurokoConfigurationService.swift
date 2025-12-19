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

    // MARK: - Agent Configuration
    public var approvalMode: ApprovalMode = .autoApprove // Changed from .alwaysAsk for testing tool functionality
    public var maxToolCallsPerRun: Int = 10
    public var responseLanguage: String = "ja" // Response language: "ja" for Japanese, "en" for English
    public var timezone: String = "Asia/Tokyo" // Timezone identifier (e.g., "Asia/Tokyo", "America/New_York")

    // MARK: - Private Properties
    private let openRouterAPIService = OpenRouterAPIService()
    private let modelsCacheKey = "openRouterModelsCache"

    // MARK: - Fixed System Instructions
    public static let FIXED_SYSTEM_PROMPT = """
あなたは自律的な汎用エージェントである。

## 存在目的
ユーザーの課題を解決し、目標達成を支援すること。

## 行動原則
1. 完全性を追求せよ：解決に必要な情報が揃うまで収集を続けよ
2. 効率を最適化せよ：最小の労力で最大の効果を求めよ
3. 安全性を確保せよ：破壊的な行動を避け、常に安全策を選択せよ
4. 透明性を維持せよ：判断プロセスと決定根拠を説明せよ

## 責任の所在
- 課題解決の主導権を担う
- 必要に応じて情報を収集し、判断を下す
- 実行可能な解決策を提示し、実装する
- リスクを評価し、適切な対策を講じる

## 制約条件
- 許可されていない領域に踏み込まない
- システムの安定性を損なう操作を避ける
- ユーザーのプライバシーとセキュリティを尊重する
- 倫理的・法的制約を守る

## 現在の情報
- 現在の日時: [DYNAMIC_TIMESTAMP]
- タイムゾーン: [TIMEZONE_INFO]

## 応答原則
- 解決に至るまで思考を続けよ
- 必要に応じてツールを使用せよ
- 最終的な解決策を提示せよ
- 実行過程を透明に説明せよ

## コミュニケーション
- ユーザー向け最終回答は<response>タグで囲む
- 内部思考プロセスは<thinking>タグで囲む
- ツール使用時はtool_call JSON形式を使用

AVAILABLE TOOLS (INJECTED AT RUNTIME)

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
        // Force auto-approve for tool calls to ensure they execute
        approvalMode = .autoApprove
        maxToolCallsPerRun = UserDefaults.standard.integer(forKey: "maxToolCallsPerRun")
        if maxToolCallsPerRun == 0 { maxToolCallsPerRun = 10 }
        responseLanguage = UserDefaults.standard.string(forKey: "responseLanguage") ?? "ja"
        timezone = UserDefaults.standard.string(forKey: "timezone") ?? "Asia/Tokyo"
    }

    /// Save all configuration to UserDefaults.
    public func saveConfiguration() {
        UserDefaults.standard.set(openRouterApiKey, forKey: "openRouterApiKey")
        UserDefaults.standard.set(selectedModelId, forKey: "selectedModelId")
        UserDefaults.standard.set(customPrompt, forKey: "customPrompt")
        UserDefaults.standard.set(googleSearchApiKey, forKey: "googleSearchApiKey")
        UserDefaults.standard.set(googleSearchEngineId, forKey: "googleSearchEngineId")
        UserDefaults.standard.set(approvalMode.rawValue, forKey: "approvalMode")
        UserDefaults.standard.set(maxToolCallsPerRun, forKey: "maxToolCallsPerRun")
        UserDefaults.standard.set(responseLanguage, forKey: "responseLanguage")
        UserDefaults.standard.set(timezone, forKey: "timezone")
    }

    /// Creates an `AgentConfig` object from the current service configuration.
    public func createAgentConfig() -> AgentConfig {
        return AgentConfig(
            approvalMode: self.approvalMode,
            maxToolCallsPerRun: self.maxToolCallsPerRun
        )
    }

    /// Get the combined system prompt (fixed + custom instructions).
    public func getCombinedPrompt() -> String {
        let timestamp = getCurrentTimestampInTimezone()
        let timezoneInfo = getTimezoneDisplayName()
        let promptWithTimestamp = Self.FIXED_SYSTEM_PROMPT
            .replacingOccurrences(of: "[DYNAMIC_TIMESTAMP]", with: timestamp)
            .replacingOccurrences(of: "[TIMEZONE_INFO]", with: timezoneInfo)

        let dynamicToolsDescription = generateDynamicToolsDescription()
        let enhancedPrompt = promptWithTimestamp.replacingOccurrences(of: "[DYNAMIC_TOOLS]", with: dynamicToolsDescription)

        if customPrompt.isEmpty {
            return enhancedPrompt
        } else {
            return enhancedPrompt + "\n\n## Custom Instructions:\n" + customPrompt
        }
    }

    // MARK: - Helpers
    private func getCurrentTimestampInTimezone() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        if let tz = TimeZone(identifier: timezone) {
            formatter.timeZone = tz
        }
        return formatter.string(from: Date())
    }

    private func getTimezoneDisplayName() -> String {
        if let tz = TimeZone(identifier: timezone) {
            let seconds = tz.secondsFromGMT()
            let absSeconds = abs(seconds)
            let hours = absSeconds / 3600
            let minutes = (absSeconds % 3600) / 60
            let sign = seconds >= 0 ? "+" : "-"
            let abbr = tz.abbreviation() ?? "GMT"
            let offset = String(format: "%@%02d:%02d", sign, hours, minutes)
            return "\(tz.identifier) (\(abbr), GMT\(offset))"
        } else {
            return timezone
        }
    }

    /// Generates a dynamic description of available tools for inclusion in the system prompt.
    private func generateDynamicToolsDescription() -> String {
        let availableTools = ToolRegistry.shared.getAvailableTools()

        if availableTools.isEmpty {
            return "\nNo additional tools are currently available."
        }

        let toolDescriptions: [String] = availableTools.map { tool in
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
        }

        return toolDescriptions.joined(separator: "\n\n")
    }
}
