import Foundation

// MARK: - Reflection Service

/// Service for analyzing task execution and generating insights for improvement
@Observable
public class ReflectionService {
    // MARK: - Properties

    private let llmService: LLMService
    private let memoryService: AgentMemoryService

    // MARK: - Initialization

    public init(llmService: LLMService, memoryService: AgentMemoryService) {
        self.llmService = llmService
        self.memoryService = memoryService
    }

    // MARK: - Core Reflection Methods

    /// Performs comprehensive reflection on task execution
    public func reflect(on execution: ExecutionResult) async throws -> ReflectionInsight {
        print("[REFLECT] Starting comprehensive reflection analysis...")

        // Generate initial insights using LLM
        let initialInsights = try await generateInitialInsights(from: execution)

        // Analyze patterns and extract key learnings
        let patternAnalysis = try await analyzePatterns(from: execution)

        // Generate improvement recommendations
        let recommendations = try await generateRecommendations(execution: execution, insights: initialInsights)

        // Create final reflection insight
        let reflectionInsight = ReflectionInsight(
            executionResult: execution,
            initialInsights: initialInsights,
            patternAnalysis: patternAnalysis,
            recommendations: recommendations,
            generatedAt: Date()
        )

        // Store learnings in memory
        try await storeLearnings(from: reflectionInsight)

        print("[REFLECT] Reflection completed with \(recommendations.count) recommendations")
        return reflectionInsight
    }

    /// Performs quick reflection for simple tasks
    public func quickReflect(on execution: ExecutionResult) async throws -> [String] {
        let prompt = """
以下のタスク実行を簡単に振り返り、3つ以内の主要な知見を抽出してください：

タスク: \(execution.originalTask)
実行時間: \(String(format: "%.1f", execution.duration))秒
成功: \(execution.success ? "はい" : "いいえ")

実行ステップ数: \(execution.steps.count)

主要な知見を簡潔に記載してください。
"""

        let config = LLMConfig(model: KurokoConfigurationService.shared.selectedModel)
        var response = ""

        try await llmService.sendMessage(
            message: prompt,
            history: [],
            config: config,
            onChunk: { chunk in
                response += chunk
            },
            onToolCall: { _ in }
        )

        // Parse insights from response
        let insights = response.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("タスク:") && !$0.hasPrefix("実行時間:") && !$0.hasPrefix("成功:") }
            .prefix(3)
            .map { $0 }

        return Array(insights)
    }

    // MARK: - Analysis Methods

    private func generateInitialInsights(from execution: ExecutionResult) async throws -> [ReflectionInsight.Insight] {
        let prompt = """
以下のタスク実行を分析し、詳細な洞察を生成してください：

タスク: \(execution.originalTask)
実行時間: \(String(format: "%.2f", execution.duration))秒
結果: \(execution.success ? "成功" : "失敗")

実行ステップ:
\(execution.steps.enumerated().map { "ステップ \($0.offset + 1): \($0.element.description) - 時間: \(String(format: "%.2f", $0.element.duration))秒" }.joined(separator: "\n"))

以下の観点から分析してください：
1. 効率性: 実行時間は適切か？無駄なステップはないか？
2. 効果性: 各ステップは目的に合っているか？
3. 安全性: リスクは適切に管理されていたか？
4. 完全性: 必要な処理がすべて実行されたか？
5. 適応性: 状況変化への対応は適切だったか？

各観点について具体的な洞察を述べてください。
"""

        let config = LLMConfig(model: KurokoConfigurationService.shared.selectedModel)
        var response = ""

        try await llmService.sendMessage(
            message: prompt,
            history: [],
            config: config,
            onChunk: { chunk in
                response += chunk
            },
            onToolCall: { _ in }
        )

        // Parse insights from structured response
        return parseInsights(from: response, category: .initialAnalysis)
    }

    private func analyzePatterns(from execution: ExecutionResult) async throws -> [ReflectionInsight.Pattern] {
        // Get historical execution data from memory
        let historicalTasks = try await memoryService.searchLongTermMemory(
            query: execution.originalTask,
            maxResults: 5
        )

        if historicalTasks.isEmpty {
            return []
        }

        let prompt = """
以下の過去の類似タスク実行と比較して、パターンを分析してください：

現在のタスク: \(execution.originalTask)
現在の実行時間: \(String(format: "%.2f", execution.duration))秒
現在のステップ数: \(execution.steps.count)

過去の実行履歴:
\(historicalTasks.map { "・\($0.content)" }.joined(separator: "\n"))

以下の観点からパターンを分析してください：
1. 実行時間の傾向（短くなっている/長くなっている）
2. ステップ数の変化
3. 成功率の改善
4. 繰り返し発生する問題点
5. 効果的な解決パターン

パターン分析を述べてください。
"""

        let config = LLMConfig(model: KurokoConfigurationService.shared.selectedModel)
        var response = ""

        try await llmService.sendMessage(
            message: prompt,
            history: [],
            config: config,
            onChunk: { chunk in
                response += chunk
            },
            onToolCall: { _ in }
        )

        // Parse patterns from response
        return parsePatterns(from: response)
    }

    private func generateRecommendations(execution: ExecutionResult, insights: [ReflectionInsight.Insight]) async throws -> [ReflectionInsight.Recommendation] {
        let insightsText = insights.map { "・\($0.title): \($0.description)" }.joined(separator: "\n")

        let prompt = """
以下の分析結果に基づいて、具体的な改善 recommendations を生成してください：

タスク: \(execution.originalTask)
実行時間: \(String(format: "%.2f", execution.duration))秒

分析結果:
\(insightsText)

以下のカテゴリの改善 recommendations を提案してください：
1. プロセス改善: 実行手順の改善
2. ツール活用: より適切なツールの選択
3. 効率化: 時間の短縮
4. 品質向上: 結果の改善
5. 予防策: 問題の未然防止

各 recommendations は具体的で実行可能なものにしてください。
"""

        let config = LLMConfig(model: KurokoConfigurationService.shared.selectedModel)
        var response = ""

        try await llmService.sendMessage(
            message: prompt,
            history: [],
            config: config,
            onChunk: { chunk in
                response += chunk
            },
            onToolCall: { _ in }
        )

        // Parse recommendations from response
        return parseRecommendations(from: response)
    }

    // MARK: - Storage Methods

    private func storeLearnings(from insight: ReflectionInsight) async throws {
        // Store key insights as long-term memory
        for recommendation in insight.recommendations where recommendation.priority >= 0.7 {
            let learningEntry = MemoryEntry(
                category: .taskLearning,
                content: """
タスクタイプ: \(insight.executionResult.originalTask.components(separatedBy: " ").first ?? "一般タスク")
改善点: \(recommendation.title)
詳細: \(recommendation.description)
影響度: \(String(format: "%.1f", recommendation.impact))
""",
                tags: ["reflection", "improvement", insight.executionResult.success ? "success" : "failure"],
                importance: recommendation.priority
            )

            try await memoryService.storeLongTermMemory(learningEntry)
        }

        // Store pattern analysis if significant
        if !insight.patternAnalysis.isEmpty {
            let patternEntry = MemoryEntry(
                category: .domainKnowledge,
                content: """
タスク: \(insight.executionResult.originalTask)
パターン分析: \(insight.patternAnalysis.map { $0.description }.joined(separator: "; "))
知見: \(insight.initialInsights.map { $0.description }.joined(separator: "; "))
""",
                tags: ["pattern", "analysis"],
                importance: 0.6
            )

            try await memoryService.storeLongTermMemory(patternEntry)
        }
    }

    // MARK: - Parsing Methods

    private func parseInsights(from response: String, category: ReflectionInsight.InsightCategory) -> [ReflectionInsight.Insight] {
        let lines = response.components(separatedBy: .newlines)
        var insights: [ReflectionInsight.Insight] = []
        var currentInsight: (title: String, description: String)?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Look for numbered insights
            if let range = trimmed.range(of: #"^\d+\."#, options: .regularExpression) {
                // Save previous insight if exists
                if let insight = currentInsight {
                    insights.append(ReflectionInsight.Insight(
                        title: insight.title,
                        description: insight.description,
                        category: category,
                        confidence: 0.8
                    ))
                }

                // Start new insight
                let title = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                currentInsight = (title: title, description: "")
            } else if let insight = currentInsight {
                // Continue building description
                currentInsight = (title: insight.title, description: insight.description + (insight.description.isEmpty ? "" : " ") + trimmed)
            }
        }

        // Save final insight
        if let insight = currentInsight {
            insights.append(ReflectionInsight.Insight(
                title: insight.title,
                description: insight.description,
                category: category,
                confidence: 0.8
            ))
        }

        return insights
    }

    private func parsePatterns(from response: String) -> [ReflectionInsight.Pattern] {
        // Simple pattern extraction - can be enhanced with more sophisticated parsing
        let patterns = response.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ReflectionInsight.Pattern(description: $0, frequency: 1, trend: .stable) }

        return patterns
    }

    private func parseRecommendations(from response: String) -> [ReflectionInsight.Recommendation] {
        let lines = response.components(separatedBy: .newlines)
        var recommendations: [ReflectionInsight.Recommendation] = []
        var currentRec: (title: String, description: String)?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Look for numbered recommendations
            if let range = trimmed.range(of: #"^\d+\."#, options: .regularExpression) {
                // Save previous recommendation if exists
                if let rec = currentRec {
                    recommendations.append(ReflectionInsight.Recommendation(
                        title: rec.title,
                        description: rec.description,
                        category: .process,
                        priority: 0.7,
                        impact: 0.6,
                        effort: .medium
                    ))
                }

                // Start new recommendation
                let title = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                currentRec = (title: title, description: "")
            } else if let rec = currentRec {
                // Continue building description
                currentRec = (title: rec.title, description: rec.description + (rec.description.isEmpty ? "" : " ") + trimmed)
            }
        }

        // Save final recommendation
        if let rec = currentRec {
            recommendations.append(ReflectionInsight.Recommendation(
                title: rec.title,
                description: rec.description,
                category: .process,
                priority: 0.7,
                impact: 0.6,
                effort: .medium
            ))
        }

        return recommendations
    }
}

// MARK: - Reflection Insight

/// Comprehensive reflection result containing analysis and recommendations
public struct ReflectionInsight {
    public let executionResult: ExecutionResult
    public let initialInsights: [Insight]
    public let patternAnalysis: [Pattern]
    public let recommendations: [Recommendation]
    public let generatedAt: Date

    // MARK: - Nested Types

    public enum InsightCategory {
        case initialAnalysis
        case patternRecognition
        case performanceAnalysis
    }

    public struct Insight {
        public let title: String
        public let description: String
        public let category: InsightCategory
        public let confidence: Double
    }

    public enum Trend {
        case improving
        case declining
        case stable
        case variable
    }

    public struct Pattern {
        public let description: String
        public let frequency: Int
        public let trend: Trend
    }

    public enum RecommendationCategory {
        case process
        case tools
        case efficiency
        case quality
        case prevention
    }

    public enum EffortLevel {
        case low
        case medium
        case high
    }

    public struct Recommendation {
        public let title: String
        public let description: String
        public let category: RecommendationCategory
        public let priority: Double // 0.0 - 1.0
        public let impact: Double   // 0.0 - 1.0
        public let effort: EffortLevel
    }
}
