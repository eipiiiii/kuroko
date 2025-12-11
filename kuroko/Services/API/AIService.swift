import Foundation

// MARK: - AI Service Protocol

protocol AIServiceProtocol {
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws
    
    func executeToolCall(_ toolCall: ToolCall) async throws -> String
    
    func updateModelConfiguration()
}

// MARK: - AI Service

/// Handles all AI provider interactions including tool calling
class AIService: AIServiceProtocol {
    let configService: APIConfigurationService
    private let searchService: SearchService
    let geminiService: GeminiServiceProtocol
    let openRouterService: OpenRouterServiceProtocol

    init(
        configService: APIConfigurationService = .shared,
        searchService: SearchService = .shared,
        geminiService: GeminiServiceProtocol = GeminiService(),
        openRouterService: OpenRouterServiceProtocol = OpenRouterService()
    ) {
        self.configService = configService
        self.searchService = searchService
        self.geminiService = geminiService
        self.openRouterService = openRouterService
    }
    
    func updateModelConfiguration() {
        if let gemini = geminiService as? GeminiService {
            gemini.updateModelConfiguration()
        }
        if let openrouter = openRouterService as? OpenRouterService {
            // openrouter.updateModelConfiguration()
        }
    }
    
    /// Send a message to AI provider with streaming support
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws {
        let provider = configService.selectedProvider
        if provider == "openrouter" {
            try await openRouterService.sendMessage(message, history: history, onChunk: onChunk, onToolCall: onToolCall)
        } else if provider == "gemini" {
            try await geminiService.sendMessage(message, history: history, onChunk: onChunk, onToolCall: onToolCall)
        }
    }
    
    /// Execute a tool call and return the result
    func executeToolCall(_ toolCall: ToolCall) async throws -> String {
        let functionName = toolCall.function.name
        
        // Parse arguments
        guard let argsData = toolCall.function.arguments.data(using: .utf8),
              let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            throw AIServiceError.invalidToolArguments
        }
        
        switch functionName {
        case "google_search":
            guard let query = argsDict["query"] as? String else {
                throw AIServiceError.invalidToolArguments
            }
            return try await searchService.performSearch(
                query: query,
                apiKey: configService.googleSearchApiKey,
                engineId: configService.googleSearchEngineId
            )
            
        case "list_directory":
            guard let path = argsDict["path"] as? String else {
                throw AIServiceError.invalidToolArguments
            }
            let fileSystemService = FileSystemService.shared
            let listing = try await fileSystemService.listDirectory(path: path)
            
            // Format the result as a readable string
            var result = "📂 Directory: \(listing.path)\n"
            result += "Total items: \(listing.totalCount)\n\n"
            
            for file in listing.files {
                let icon = file.isDirectory ? "📁" : "📄"
                let size = file.size.map { "\($0) bytes" } ?? ""
                result += "\(icon) \(file.name) \(size)\n"
            }
            
            return result
            
        case "read_file":
            guard let path = argsDict["path"] as? String else {
                throw AIServiceError.invalidToolArguments
            }
            let fileSystemService = FileSystemService.shared
            let content = try await fileSystemService.readFile(path: path)
            return "📄 File: \(path)\n\n\(content)"
            
        case "write_file":
            guard let path = argsDict["path"] as? String,
                  let content = argsDict["content"] as? String else {
                throw AIServiceError.invalidToolArguments
            }
            let fileSystemService = FileSystemService.shared
            
            // Check if file exists to determine create vs write
            if fileSystemService.fileExists(path: path) {
                try await fileSystemService.writeFile(path: path, content: content)
                return "✅ File updated successfully: \(path)"
            } else {
                try await fileSystemService.createFile(path: path, content: content)
                return "✅ File created successfully: \(path)"
            }
            
        case "delete_file":
            guard let path = argsDict["path"] as? String else {
                throw AIServiceError.invalidToolArguments
            }
            let fileSystemService = FileSystemService.shared
            try await fileSystemService.deleteFile(path: path)
            return "✅ File deleted successfully: \(path)"
            
        default:
            throw AIServiceError.unsupportedTool(functionName)
        }
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case providerNotConfigured
    case unsupportedTool(String)
    case invalidToolArguments
    
    var errorDescription: String? {
        switch self {
        case .providerNotConfigured:
            return "AI provider is not configured."
        case .unsupportedTool(let name):
            return "Unsupported tool: \(name)"
        case .invalidToolArguments:
            return "Invalid tool arguments"
        }
    }
}
