import Foundation

// MARK: - Agent Memory Service

/// Service for managing agent memory including working memory and long-term memory
@Observable
public class AgentMemoryService {
    // MARK: - Properties

    /// Working memory for current session context
    public private(set) var workingMemory: [MemoryEntry] = []

    /// Long-term memory store
    private let longTermMemory: LongTermMemoryStore

    // MARK: - Initialization

    public init() {
        self.longTermMemory = FileBasedLongTermMemory()
    }

    // MARK: - Working Memory Management

    /// Adds an entry to working memory
    public func addToWorkingMemory(_ entry: MemoryEntry) {
        workingMemory.append(entry)

        // Limit working memory size
        if workingMemory.count > 50 { // Keep last 50 entries
            workingMemory.removeFirst(workingMemory.count - 50)
        }
    }

    /// Clears working memory
    public func clearWorkingMemory() {
        workingMemory.removeAll()
    }

    /// Retrieves relevant working memory for a query
    public func getRelevantWorkingMemory(for query: String, maxResults: Int = 10) -> [MemoryEntry] {
        let queryLower = query.lowercased()
        let scored = workingMemory.map { entry -> (entry: MemoryEntry, score: Double) in
            let score = calculateRelevanceScore(entry: entry, query: queryLower)
            return (entry, score)
        }
        .filter { $0.score > 0.1 } // Minimum relevance threshold
        .sorted { $0.score > $1.score }

        return Array(scored.prefix(maxResults).map { $0.entry })
    }

    // MARK: - Long-term Memory Management

    /// Stores memory in long-term storage
    public func storeLongTermMemory(_ entry: MemoryEntry) async throws {
        try await longTermMemory.store(entry)
    }

    /// Searches long-term memory for relevant entries
    public func searchLongTermMemory(query: String, maxResults: Int = 5) async -> [MemoryEntry] {
        return await longTermMemory.search(query: query, maxResults: maxResults)
    }

    /// Retrieves memory entries by category
    public func getMemoriesByCategory(_ category: MemoryCategory, maxResults: Int = 20) async throws -> [MemoryEntry] {
        return try await longTermMemory.getByCategory(category, maxResults: maxResults)
    }

    /// Updates importance score of a memory entry
    public func updateMemoryImportance(id: UUID, newImportance: Double) async throws {
        try await longTermMemory.updateImportance(id: id, importance: newImportance)
    }

    // MARK: - Context Integration

    /// Gets relevant context for a task by combining working and long-term memory
    public func getContextForTask(_ taskDescription: String) async throws -> String {
        // Search working memory
        let workingContext = getRelevantWorkingMemory(for: taskDescription, maxResults: 5)
        let workingText = workingContext.map { "作業メモリ: \($0.content)" }.joined(separator: "\n")

        // Search long-term memory
        let longTermContext = await searchLongTermMemory(query: taskDescription, maxResults: 5)
        let longTermText = longTermContext.map { "長期記憶: \($0.content)" }.joined(separator: "\n")

        var contextParts: [String] = []
        if !workingText.isEmpty {
            contextParts.append("=== 作業メモリ ===\n\(workingText)")
        }
        if !longTermText.isEmpty {
            contextParts.append("=== 長期記憶 ===\n\(longTermText)")
        }

        return contextParts.joined(separator: "\n\n")
    }

    /// Learns from task execution
    public func learnFromExecution(task: String, result: ExecutionResult, insights: [String]) async throws {
        let learningEntry = MemoryEntry(
            category: .taskLearning,
            content: """
タスク: \(task)
結果: \(result.success ? "成功" : "失敗")
実行時間: \(result.duration)秒
知見: \(insights.joined(separator: ", "))
""",
            tags: ["execution", result.success ? "success" : "failure"],
            importance: result.success ? 0.7 : 0.9
        )

        try await storeLongTermMemory(learningEntry)
    }

    // MARK: - Private Methods

    private func calculateRelevanceScore(entry: MemoryEntry, query: String) -> Double {
        let content = entry.content.lowercased()
        let tags = entry.tags.joined(separator: " ").lowercased()

        var score = 0.0

        // Exact matches in content get high score
        if content.contains(query) {
            score += 1.0
        }

        // Partial matches get medium score
        let queryWords = query.split(separator: " ").map(String.init)
        for word in queryWords {
            if content.contains(word) {
                score += 0.3
            }
            if tags.contains(word) {
                score += 0.2
            }
        }

        // Recent entries get slight boost
        let hoursSinceCreation = Date().timeIntervalSince(entry.timestamp) / 3600
        let recencyBoost = max(0, 1.0 - (hoursSinceCreation / 24.0)) * 0.1
        score += recencyBoost

        // Importance multiplier
        score *= entry.importance

        return min(score, 1.0) // Cap at 1.0
    }
}

// MARK: - Memory Entry

/// Represents a single memory entry
public struct MemoryEntry: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let category: MemoryCategory
    public let content: String
    public let tags: [String]
    public let importance: Double
    public let metadata: [String: String]?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: MemoryCategory,
        content: String,
        tags: [String] = [],
        importance: Double = 0.5,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.content = content
        self.tags = tags
        self.importance = importance
        self.metadata = metadata
    }
}

// MARK: - Memory Category

/// Categories for memory classification
public enum MemoryCategory: String, Codable {
    case userPreference
    case taskLearning
    case domainKnowledge
    case toolUsagePattern
    case errorAndFix
    case conversationContext
}

// MARK: - Long-term Memory Store Protocol

/// Protocol for long-term memory storage implementations
protocol LongTermMemoryStore {
    func store(_ entry: MemoryEntry) async throws
    func search(query: String, maxResults: Int) async -> [MemoryEntry]
    func getByCategory(_ category: MemoryCategory, maxResults: Int) async throws -> [MemoryEntry]
    func updateImportance(id: UUID, importance: Double) async throws
    func delete(id: UUID) async throws
}

// MARK: - File-based Long-term Memory Implementation

/// File-based implementation of long-term memory storage
class FileBasedLongTermMemory: LongTermMemoryStore {
    private let memoryDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.memoryDirectory = appSupport.appendingPathComponent("Kuroko").appendingPathComponent("Memory")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)

        // Configure encoder/decoder
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        decoder.dateDecodingStrategy = .iso8601
    }

    func store(_ entry: MemoryEntry) async throws {
        let fileName = "\(entry.id.uuidString).json"
        let fileURL = memoryDirectory.appendingPathComponent(fileName)

        let data = try encoder.encode(entry)
        try data.write(to: fileURL, options: .atomic)
    }

    func search(query: String, maxResults: Int) async -> [MemoryEntry] {
        let allEntries = await getAllEntries()
        let queryLower = query.lowercased()

        let scored = allEntries.map { entry -> (entry: MemoryEntry, score: Double) in
            let score = calculateSearchScore(entry: entry, query: queryLower)
            return (entry, score)
        }
        .filter { $0.score > 0.1 }
        .sorted { $0.score > $1.score }

        return Array(scored.prefix(maxResults).map { $0.entry })
    }

    func getByCategory(_ category: MemoryCategory, maxResults: Int) async throws -> [MemoryEntry] {
        let allEntries = await getAllEntries()
        return allEntries
            .filter { $0.category == category }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(maxResults)
            .map { $0 }
    }

    func updateImportance(id: UUID, importance: Double) async throws {
        let fileName = "\(id.uuidString).json"
        let fileURL = memoryDirectory.appendingPathComponent(fileName)

        guard let data = try? Data(contentsOf: fileURL),
              var entry = try? decoder.decode(MemoryEntry.self, from: data) else {
            throw MemoryError.entryNotFound
        }

        entry = MemoryEntry(
            id: entry.id,
            timestamp: entry.timestamp,
            category: entry.category,
            content: entry.content,
            tags: entry.tags,
            importance: importance,
            metadata: entry.metadata
        )

        let updatedData = try encoder.encode(entry)
        try updatedData.write(to: fileURL, options: .atomic)
    }

    func delete(id: UUID) async throws {
        let fileName = "\(id.uuidString).json"
        let fileURL = memoryDirectory.appendingPathComponent(fileName)

        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Private Methods

    private func getAllEntries() async -> [MemoryEntry] {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: memoryDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return fileURLs.filter { $0.pathExtension == "json" }.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let entry = try? decoder.decode(MemoryEntry.self, from: data) else {
                return nil
            }
            return entry
        }
    }

    private func calculateSearchScore(entry: MemoryEntry, query: String) -> Double {
        let content = entry.content.lowercased()
        let tags = entry.tags.joined(separator: " ").lowercased()

        var score = 0.0

        // Exact phrase match gets highest score
        if content.contains(query) {
            score += 1.0
        }

        // Tag matches get medium score
        if tags.contains(query) {
            score += 0.7
        }

        // Individual word matches
        let queryWords = query.split(separator: " ").map(String.init)
        for word in queryWords {
            if content.contains(word) {
                score += 0.3
            }
            if tags.contains(word) {
                score += 0.2
            }
        }

        // Category relevance
        switch entry.category {
        case .taskLearning where query.contains("タスク") || query.contains("task"):
            score += 0.2
        case .errorAndFix where query.contains("エラー") || query.contains("error"):
            score += 0.2
        case .toolUsagePattern where query.contains("ツール") || query.contains("tool"):
            score += 0.2
        default:
            break
        }

        // Recency boost (newer entries slightly preferred)
        let daysSinceCreation = Date().timeIntervalSince(entry.timestamp) / (24 * 3600)
        let recencyBoost = max(0, 1.0 - (daysSinceCreation / 30.0)) * 0.1
        score += recencyBoost

        // Importance multiplier
        score *= entry.importance

        return min(score, 1.0)
    }
}

// MARK: - Memory Errors

enum MemoryError: Error {
    case entryNotFound
    case storageFailure
    case invalidData
}
