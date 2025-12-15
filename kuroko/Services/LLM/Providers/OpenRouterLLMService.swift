import Foundation

// MARK: - OpenRouter LLM Service

/// A service to interact with the OpenRouter API.
/// This class conforms to the LLMService protocol and handles the specifics of OpenRouter API calls.
public class OpenRouterLLMService: LLMService {
    
    public let provider: LLMProvider = .openRouter
    
    private let configService: KurokoConfigurationService
    private let toolRegistry: ToolRegistry // Will be created in a later step
    
    init(
        configService: KurokoConfigurationService = .shared,
        toolRegistry: ToolRegistry = .shared
    ) {
        self.configService = configService
        self.toolRegistry = toolRegistry
    }
    
    /// Sends a message to the OpenRouter API with streaming support.
    public func sendMessage(
        message: String,
        history: [ChatMessage],
        config: LLMConfig,
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
            allMessages.append(["role": "system", "content": combinedPrompt])
        }
        
        // Add history
        allMessages.append(contentsOf: history.map { $0.toOpenRouterFormat() })
        
        // Add new user message
        if !message.isEmpty {
            allMessages.append(["role": "user", "content": message])
        }
        
        // Build request body
        var requestBody: [String: Any] = [
            "model": config.model.modelName,
            "messages": allMessages,
            "stream": true
        ]
        
        // Add available tools from the registry
        let availableTools = toolRegistry.getAvailableTools()
        if !availableTools.isEmpty {
            requestBody["tools"] = availableTools.map { $0.definition }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Parse streaming response
        try parseStreamingResponse(data: data, onChunk: onChunk, onToolCall: onToolCall)
    }
    
    /// Parses the streaming response from the OpenRouter API.
    private func parseStreamingResponse(
        data: Data,
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) throws {
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
                    if let id = firstMethod["id"] as? String { currentToolId = id }
                    if let function = firstMethod["function"] as? [String: Any] {
                        if let name = function["name"] as? String { currentFunctionName = name }
                        if let args = function["arguments"] as? String { currentFunctionArgs += args }
                    }
                }
            }
        }
        
        // If a tool call was completely streamed, trigger the callback.
        if isToolCall && !currentFunctionName.isEmpty {
            let toolCall = ToolCall(
                id: currentToolId,
                type: "function",
                function: FunctionCall(name: currentFunctionName, arguments: currentFunctionArgs)
            )
            onToolCall(toolCall)
        }
    }
}

// MARK: - ChatMessage Extension

fileprivate extension ChatMessage {
    /// Converts a ChatMessage to the dictionary format expected by the OpenRouter API.
    func toOpenRouterFormat() -> [String: Any] {
        var msg: [String: Any] = [
            "role": self.role.rawValue,
            "content": self.text
        ]
        
        // Map 'model' role to 'assistant' for the API
        if self.role == .model {
            msg["role"] = "assistant"
            if let toolCalls = self.toolCalls {
                msg["tool_calls"] = toolCalls.map { tc in
                    [
                        "id": tc.id,
                        "type": tc.type,
                        "function": [
                            "name": tc.function.name,
                            "arguments": tc.function.arguments
                        ]
                    ]
                }
            }
        } else if self.role == .tool {
            msg["tool_call_id"] = self.toolCallId
        }
        
        return msg
    }
}