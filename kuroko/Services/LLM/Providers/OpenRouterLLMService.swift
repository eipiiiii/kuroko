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
        print("[LLM] Starting API request to OpenRouter")

        let url = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(configService.openRouterApiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("kuroko-swift", forHTTPHeaderField: "HTTP-Referer")
        request.addValue("kuroko-swift", forHTTPHeaderField: "X-Title")

        print("[LLM] API Key configured: \(configService.openRouterApiKey.isEmpty ? "NO" : "YES")")

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

        print("[LLM] Message count: \(allMessages.count)")

        // Build request body
        var requestBody: [String: Any] = [
            "model": config.model.modelName,
            "messages": allMessages,
            "stream": true
        ]

        print("[LLM] Using model: \(config.model.modelName)")

        // Add available tools from the registry
        let availableTools = toolRegistry.getAvailableTools()
        if !availableTools.isEmpty {
            requestBody["tools"] = availableTools.map { $0.definition }
            print("[LLM] Tools configured: \(availableTools.count)")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("[LLM] Sending request to OpenRouter API...")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("[LLM] HTTP Status: \(httpResponse.statusCode)")

                if httpResponse.statusCode != 200 {
                    let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                    print("[LLM] Error response: \(responseString)")
                    throw NSError(domain: "OpenRouter", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API returned status \(httpResponse.statusCode)"])
                }
            }

            print("[LLM] Response received, parsing stream...")

            // Parse streaming response
            try parseStreamingResponse(data: data, onChunk: onChunk, onToolCall: onToolCall)

            print("[LLM] Stream parsing completed")

        } catch {
            print("[LLM] Request failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Parses the streaming response from the OpenRouter API.
    private func parseStreamingResponse(
        data: Data,
        onChunk: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void
    ) throws {
        let responseString = String(data: data, encoding: .utf8) ?? ""
        let lines = responseString.components(separatedBy: "\n")

        var toolCallsInProgress: [Int: (id: String?, type: String?, functionName: String?, functionArgs: String?)] = [:]
        var isToolCall = false
        var finishReason: String?

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedLine.hasPrefix("data: ") {
                let jsonDataString = String(trimmedLine.dropFirst(6))

                if jsonDataString == "[DONE]" {
                    break
                }

                guard let jsonData = jsonDataString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any] else {
                    continue
                }

                // Check finish reason
                if let finish = choices.first?["finish_reason"] as? String {
                    finishReason = finish
                }

                // Handle content
                if let content = delta["content"] as? String, !content.isEmpty {
                    onChunk(content)
                }

                // Handle tool calls - accumulate across multiple deltas
                if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                    isToolCall = true
                    for toolCall in toolCalls {
                        if let toolIndex = toolCall["index"] as? Int {
                            var current = toolCallsInProgress[toolIndex] ?? (id: nil, type: nil, functionName: nil, functionArgs: nil)

                            // Update id if provided
                            if let id = toolCall["id"] as? String {
                                current.id = id
                            }

                            // Update type if provided
                            if let type = toolCall["type"] as? String {
                                current.type = type
                            }

                            // Update function info if provided
                            if let function = toolCall["function"] as? [String: Any] {
                                if let name = function["name"] as? String {
                                    current.functionName = name
                                }
                                if let args = function["arguments"] as? String {
                                    // Append to existing args if any
                                    current.functionArgs = (current.functionArgs ?? "") + args
                                }
                            }

                            toolCallsInProgress[toolIndex] = current
                        }
                    }
                }
            }
        }

        // Create tool calls when streaming is complete or finish_reason indicates tool_calls
        if isToolCall && (finishReason == "tool_calls" || finishReason == "stop") {
            for (_, toolCallInfo) in toolCallsInProgress {
                if let id = toolCallInfo.id,
                   let type = toolCallInfo.type,
                   let functionName = toolCallInfo.functionName,
                   let functionArgs = toolCallInfo.functionArgs {

                    print("[TOOL] Created: \(functionName) with args: \(functionArgs)")
                    let toolCall = ToolCall(
                        id: id,
                        type: type,
                        function: FunctionCall(name: functionName, arguments: functionArgs)
                    )
                    onToolCall(toolCall)
                }
            }
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
        
        // Map 'assistant' role to 'assistant' for the API
        if self.role == .assistant {
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
        } else if self.role == .tool || self.role == .toolResult {
            msg["role"] = "tool"
            if let toolCallId = self.toolCallId {
                msg["tool_call_id"] = toolCallId
            }
        }
        
        return msg
    }
}
