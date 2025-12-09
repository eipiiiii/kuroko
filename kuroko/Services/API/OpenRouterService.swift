import Foundation

// MARK: - OpenRouter Service Protocol

protocol OpenRouterServiceProtocol {
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws
}

// MARK: - OpenRouter Service

/// Handles all OpenRouter API interactions including tool calling
class OpenRouterService: OpenRouterServiceProtocol {
    private let configService: APIConfigurationService
    private let searchService: SearchService
    
    init(
        configService: APIConfigurationService = .shared,
        searchService: SearchService = .shared
    ) {
        self.configService = configService
        self.searchService = searchService
    }
    
    /// Send a message to OpenRouter API with streaming support
    func sendMessage(
        _ message: String,
        history: [ChatMessage],
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) async throws {
        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(configService.openRouterApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("kuroko-swift", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("kuroko-swift", forHTTPHeaderField: "X-Title")
        
        // Build messages array
        var allMessages: [[String: Any]] = []
        
        // Add system prompt
        let combinedPrompt = configService.getCombinedPrompt()
        if !combinedPrompt.isEmpty {
            allMessages.append([
                "role": "system",
                "content": combinedPrompt
            ])
        }
        
        // Add history
        let chatMessages = history.map { chatMessage -> [String: Any] in
            var msg: [String: Any] = [
                "role": chatMessage.role.rawValue,
                "content": chatMessage.text
            ]
            
            // Map 'model' role to 'assistant' for API
            if chatMessage.role == .model {
                msg["role"] = "assistant"
                if let toolCalls = chatMessage.toolCalls {
                    let toolCallsJSON = toolCalls.map { tc in
                        [
                            "id": tc.id,
                            "type": tc.type,
                            "function": [
                                "name": tc.function.name,
                                "arguments": tc.function.arguments
                            ]
                        ]
                    }
                    msg["tool_calls"] = toolCallsJSON
                }
            } else if chatMessage.role == .tool {
                msg["tool_call_id"] = chatMessage.toolCallId
            }
            
            return msg
        }
        
        allMessages.append(contentsOf: chatMessages)
        
        // Build request body
        var requestBody: [String: Any] = [
            "model": configService.selectedModel,
            "messages": allMessages,
            "stream": true
        ]
        
        // Add tools if search is configured
        let searchToolsEnabled = !configService.googleSearchApiKey.isEmpty && !configService.googleSearchEngineId.isEmpty
        
        // Check if file system access is configured
        let fileAccessManager = FileAccessManager.shared
        let fileSystemEnabled = fileAccessManager.workingDirectoryURL != nil
        
        var tools: [[String: Any]] = []
        
        if searchToolsEnabled {
            let googleSearchTool: [String: Any] = [
                "type": "function",
                "function": [
                    "name": "google_search",
                    "description": "Search Google for information when you cannot answer from your knowledge base or need up-to-date information.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "query": [
                                "type": "string",
                                "description": "The search query to send to Google."
                            ]
                        ],
                        "required": ["query"]
                    ]
                ]
            ]
            tools.append(googleSearchTool)
        }
        
        if fileSystemEnabled {
            let listDirectoryTool: [String: Any] = [
                "type": "function",
                "function": [
                    "name": "list_directory",
                    "description": "List files and directories in the specified path within the working directory.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path from working directory (use '.' for current directory)"
                            ]
                        ],
                        "required": ["path"]
                    ]
                ]
            ]
            
            let readFileTool: [String: Any] = [
                "type": "function",
                "function": [
                    "name": "read_file",
                    "description": "Read the contents of a text file.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path to the file from working directory"
                            ]
                        ],
                        "required": ["path"]
                    ]
                ]
            ]
            
            let writeFileTool: [String: Any] = [
                "type": "function",
                "function": [
                    "name": "write_file",
                    "description": "Write content to a file (creates new file or overwrites existing).",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path to the file from working directory"
                            ],
                            "content": [
                                "type": "string",
                                "description": "Content to write to the file"
                            ]
                        ],
                        "required": ["path", "content"]
                    ]
                ]
            ]
            
            let deleteFileTool: [String: Any] = [
                "type": "function",
                "function": [
                    "name": "delete_file",
                    "description": "Delete a file. Use with caution as this operation cannot be undone.",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "path": [
                                "type": "string",
                                "description": "Relative path to the file from working directory"
                            ]
                        ],
                        "required": ["path"]
                    ]
                ]
            ]
            
            tools.append(contentsOf: [listDirectoryTool, readFileTool, writeFileTool, deleteFileTool])
        }
        
        if !tools.isEmpty {
            requestBody["tools"] = tools
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse streaming response
        let responseString = String(data: data, encoding: .utf8) ?? ""
        let lines = responseString.components(separatedBy: "\n")
        
        var currentToolId: String = ""
        var currentFunctionName: String = ""
        var currentFunctionArgs: String = ""
        var isToolCall = false
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("data: ") {
                let jsonDataString = String(trimmedLine.dropFirst(6))
                if jsonDataString == "[DONE]" { break }
                
                guard let jsonData = jsonDataString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any] else { continue }
                
                // Handle content
                if let content = delta["content"] as? String, !content.isEmpty {
                    onChunk(content)
                }
                
                // Handle tool calls
                if let toolCalls = delta["tool_calls"] as? [[String: Any]], let firstMethod = toolCalls.first {
                    isToolCall = true
                    if let id = firstMethod["id"] as? String {
                        currentToolId = id
                    }
                    if let function = firstMethod["function"] as? [String: Any] {
                        if let name = function["name"] as? String {
                            currentFunctionName = name
                        }
                        if let args = function["arguments"] as? String {
                            currentFunctionArgs += args
                        }
                    }
                }
            }
        }
        
        // If tool call completed, notify
        if isToolCall && !currentFunctionName.isEmpty {
            let toolCall = ToolCall(
                id: currentToolId,
                type: "function",
                function: FunctionCall(name: currentFunctionName, arguments: currentFunctionArgs)
            )
            onToolCall(toolCall)
        }
    }
    
    /// Execute a tool call and return the result
    func executeToolCall(_ toolCall: ToolCall) async throws -> String {
        let functionName = toolCall.function.name
        
        // Parse arguments
        guard let argsData = toolCall.function.arguments.data(using: .utf8),
              let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            throw OpenRouterServiceError.invalidToolArguments
        }
        
        switch functionName {
        case "google_search":
            guard let query = argsDict["query"] as? String else {
                throw OpenRouterServiceError.invalidToolArguments
            }
            return try await searchService.performSearch(
                query: query,
                apiKey: configService.googleSearchApiKey,
                engineId: configService.googleSearchEngineId
            )
            
        case "list_directory":
            guard let path = argsDict["path"] as? String else {
                throw OpenRouterServiceError.invalidToolArguments
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
                throw OpenRouterServiceError.invalidToolArguments
            }
            let fileSystemService = FileSystemService.shared
            let content = try await fileSystemService.readFile(path: path)
            return "📄 File: \(path)\n\n\(content)"
            
        case "write_file":
            guard let path = argsDict["path"] as? String,
                  let content = argsDict["content"] as? String else {
                throw OpenRouterServiceError.invalidToolArguments
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
                throw OpenRouterServiceError.invalidToolArguments
            }
            let fileSystemService = FileSystemService.shared
            try await fileSystemService.deleteFile(path: path)
            return "✅ File deleted successfully: \(path)"
            
        default:
            throw OpenRouterServiceError.unsupportedTool(functionName)
        }
    }
}

// MARK: - Errors

enum OpenRouterServiceError: LocalizedError {
    case unsupportedTool(String)
    case invalidToolArguments
    
    var errorDescription: String? {
        switch self {
        case .unsupportedTool(let name):
            return "Unsupported tool: \(name)"
        case .invalidToolArguments:
            return "Invalid tool arguments"
        }
    }
}
