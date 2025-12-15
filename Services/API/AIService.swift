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

/// Handles OpenRouter AI provider interactions including tool calling with enhanced error handling
class AIService: AIServiceProtocol {
    let configService: APIConfigurationService
    private let searchService: SearchService
    let openRouterService: OpenRouterServiceProtocol

    init(
        configService: APIConfigurationService = .shared,
        searchService: SearchService = .shared,
        openRouterService: OpenRouterServiceProtocol = OpenRouterService()
    ) {
        self.configService = configService
        self.searchService = searchService
        self.openRouterService = openRouterService
    }
    
    func updateModelConfiguration() {
        if let openrouter = openRouterService as? OpenRouterService {
            // openrouter.updateModelConfiguration()
        }
    }
    
    /// Send a message to OpenRouter with streaming support
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws {
        // Always use OpenRouter
        try await openRouterService.sendMessage(message, history: history, onChunk: onChunk, onToolCall: onToolCall)
    }
    
    /// Execute a tool call and return the result with enhanced error handling
    func executeToolCall(_ toolCall: ToolCall) async throws -> String {
        let functionName = toolCall.function.name
        
        // Validate and parse arguments with detailed error reporting
        let argsDict: [String: Any]
        do {
            argsDict = try validateAndParseArguments(toolCall.function.arguments)
        } catch {
            throw AIServiceError.invalidToolArgumentsDetailed(functionName, error.localizedDescription)
        }
        
        // Log tool execution for debugging
        print("🔧 Executing tool: \(functionName) with arguments: \(argsDict)")
        
        // Execute with timeout protection
        return try await withTimeout(.seconds(30)) {
            try await executeToolSafely(functionName, arguments: argsDict)
        }
    }
    
    /// Validate and parse tool arguments
    private func validateAndParseArguments(_ argumentsString: String) throws -> [String: Any] {
        guard let argsData = argumentsString.data(using: .utf8) else {
            throw ToolError.invalidJSONEncoding
        }
        
        guard let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            throw ToolError.invalidJSONStructure
        }
        
        return argsDict
    }
    
    /// Execute tool safely with proper error handling
    private func executeToolSafely(_ functionName: String, arguments argsDict: [String: Any]) async throws -> String {
        switch functionName {
        case "google_search":
            return try await executeGoogleSearch(argsDict)
            
        case "list_directory":
            return try await executeListDirectory(argsDict)
            
        case "read_file":
            return try await executeReadFile(argsDict)
            
        case "write_file":
            return try await executeWriteFile(argsDict)
            
        case "delete_file":
            return try await executeDeleteFile(argsDict)
            
        default:
            throw AIServiceError.unsupportedTool(functionName)
        }
    }
    
    /// Execute Google search with validation
    private func executeGoogleSearch(_ argsDict: [String: Any]) async throws -> String {
        guard let query = argsDict["query"] as? String, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolError.missingRequiredParameter("query")
        }
        
        return try await searchService.performSearch(
            query: query,
            apiKey: configService.googleSearchApiKey,
            engineId: configService.googleSearchEngineId
        )
    }
    
    /// Execute directory listing with path validation
    private func executeListDirectory(_ argsDict: [String: Any]) async throws -> String {
        guard let path = argsDict["path"] as? String else {
            throw ToolError.missingRequiredParameter("path")
        }
        
        let validatedPath = try validateFilePath(path)
        let fileSystemService = FileSystemService.shared
        let listing = try await fileSystemService.listDirectory(path: validatedPath)
        
        // Format the result as a readable string
        var result = "📂 Directory: \(listing.path)\n"
        result += "Total items: \(listing.totalCount)\n\n"
        
        for file in listing.files {
            let icon = file.isDirectory ? "📁" : "📄"
            let size = file.size.map { "\($0) bytes" } ?? ""
            result += "\(icon) \(file.name) \(size)\n"
        }
        
        return result
    }
    
    /// Execute file read with path validation
    private func executeReadFile(_ argsDict: [String: Any]) async throws -> String {
        guard let path = argsDict["path"] as? String else {
            throw ToolError.missingRequiredParameter("path")
        }
        
        let validatedPath = try validateFilePath(path)
        let fileSystemService = FileSystemService.shared
        
        // Check if file exists
        guard fileSystemService.fileExists(path: validatedPath) else {
            throw ToolError.fileNotFound(validatedPath)
        }
        
        let content = try await fileSystemService.readFile(path: validatedPath)
        return "📄 File: \(validatedPath)\n\n\(content)"
    }
    
    /// Execute file write with validation
    private func executeWriteFile(_ argsDict: [String: Any]) async throws -> String {
        guard let path = argsDict["path"] as? String, let content = argsDict["content"] as? String else {
            throw ToolError.missingRequiredParameter("path or content")
        }
        
        let validatedPath = try validateFilePath(path)
        let fileSystemService = FileSystemService.shared
        
        // Check if file exists to determine create vs write
        if fileSystemService.fileExists(path: validatedPath) {
            try await fileSystemService.writeFile(path: validatedPath, content: content)
            return "✅ File updated successfully: \(validatedPath)"
        } else {
            try await fileSystemService.createFile(path: validatedPath, content: content)
            return "✅ File created successfully: \(validatedPath)"
        }
    }
    
    /// Execute file deletion with safety checks
    private func executeDeleteFile(_ argsDict: [String: Any]) async throws -> String {
        guard let path = argsDict["path"] as? String else {
            throw ToolError.missingRequiredParameter("path")
        }
        
        let validatedPath = try validateFilePath(path)
        let fileSystemService = FileSystemService.shared
        
        // Check if file exists
        guard fileSystemService.fileExists(path: validatedPath) else {
            throw ToolError.fileNotFound(validatedPath)
        }
        
        try await fileSystemService.deleteFile(path: validatedPath)
        return "✅ File deleted successfully: \(validatedPath)"
    }
    
    /// Validate file path for security
    private func validateFilePath(_ path: String) throws -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty path
        guard !trimmedPath.isEmpty else {
            throw ToolError.invalidPath("Empty path")
        }
        
        // Check for path traversal attempts
        if trimmedPath.contains("..") {
            throw ToolError.invalidPath("Path traversal not allowed")
        }
        
        return trimmedPath
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case providerNotConfigured
    case unsupportedTool(String)
    case invalidToolArguments
    case invalidToolArgumentsDetailed(String, String)
    
    var errorDescription: String? {
        switch self {
        case .providerNotConfigured:
            return "OpenRouter is not configured."
        case .unsupportedTool(let name):
            return "Unsupported tool: \(name)"
        case .invalidToolArguments:
            return "Invalid tool arguments"
        case .invalidToolArgumentsDetailed(let toolName, let details):
            return "Invalid tool arguments for \(toolName): \(details)"
        }
    }
}

enum ToolError: LocalizedError {
    case invalidJSONEncoding
    case invalidJSONStructure
    case missingRequiredParameter(String)
    case invalidPath(String)
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSONEncoding:
            return "Tool arguments are not properly encoded"
        case .invalidJSONStructure:
            return "Tool arguments have invalid JSON structure"
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidPath(let reason):
            return "Invalid file path: \(reason)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}
