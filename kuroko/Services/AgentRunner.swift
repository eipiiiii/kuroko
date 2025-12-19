import Foundation

// MARK: - Agent Runner

/// The core agent runner that implements the Cline-style flow with state machine.
public class AgentRunner {
    // MARK: - Properties

    private var state: AgentState = .idle
    private var messages: [ChatMessage] = []
    private var toolCallCount: Int = 0
    private var threadGrant: Bool = false // For perThread approval mode
    private let config: AgentConfig
    private let llmService: LLMService
    private let toolExecutor: ToolExecutor
    private let systemPrompt: String

    // MARK: - Callbacks

    public var onStateChange: ((AgentState) -> Void)?
    public var onMessageAdded: ((ChatMessage) -> Void)?

    // MARK: - Initialization

    public init(
        config: AgentConfig = AgentConfig(),
        llmService: LLMService,
        toolExecutor: ToolExecutor,
        systemPrompt: String
    ) {
        self.config = config
        self.llmService = llmService
        self.toolExecutor = toolExecutor
        self.systemPrompt = systemPrompt
    }

    // MARK: - Public Methods

    /// Starts the agent with a user message.
    public func start(with userMessage: String) async throws {
        switch state {
        case .idle, .completed, .failed:
            // Allow starting a new run if the agent is idle or has finished a previous run.
            break
        default:
            // If the agent is in any other state (e.g., awaitingLLM, awaitingApproval), it's busy.
            return
        }

        // Add user message to conversation history
        messages.append(ChatMessage(role: .user, text: userMessage))

        toolCallCount = 0
        threadGrant = false

        await transition(to: .awaitingLLM)
        try await runLoop()
    }

    /// Starts the agent with a full conversation history.
    public func startWithHistory(_ conversationHistory: [ChatMessage]) async throws {
        switch state {
        case .idle, .completed, .failed:
            // Allow starting a new run if the agent is idle or has finished a previous run.
            break
        default:
            // If the agent is in any other state (e.g., awaitingLLM, awaitingApproval), it's busy.
            return
        }

        // Set conversation history with system prompt at the beginning
        messages = [ChatMessage(role: .system, text: systemPrompt)] + conversationHistory

        toolCallCount = 0
        threadGrant = false

        await transition(to: .awaitingLLM)
        try await runLoop()
    }

    /// Approves a pending tool call.
    public func approveToolCall() async throws {
        guard case .awaitingApproval(let proposal) = state else { return }
        threadGrant = true
        await transition(to: .executingTool(proposal))
        try await runLoop() // Resume the loop
    }

    /// Rejects a pending tool call.
    public func rejectToolCall() async throws {
        guard case .awaitingApproval = state else { return }
        await transition(to: .completed)
    }

    // MARK: - Private Methods

    private func runLoop() async throws {
        while true {
            switch state {
            case .awaitingLLM:
                try await callLLM()

            case .toolProposed(let proposal):
                if needsApproval(for: proposal) {
                    await transition(to: .awaitingApproval(proposal))
                    return // Exit loop and wait for user approval
                } else {
                    await transition(to: .executingTool(proposal))
                    // Continue loop to .executingTool case
                }

            case .executingTool(let proposal):
                try await executeTool(proposal)
                // Continue loop to .awaitingLLM case

            case .completed, .failed, .awaitingApproval:
                return // Final states, exit loop

            default:
                return
            }
        }
    }

    private func callLLM() async throws {
        let config = LLMConfig(model: KurokoConfigurationService.shared.selectedModel)

        var assistantMessage = ChatMessage(role: .assistant, text: "", isStreaming: true)
        messages.append(assistantMessage)
        onMessageAdded?(assistantMessage)

        var responseText = ""
        var receivedToolCall: ToolCall?

        try await llmService.sendMessage(
            message: "", // Not used in this flow
            history: messages.dropLast(), // Exclude the current assistant message
            config: config,
            onChunk: { [weak self] chunk in
                guard let self = self else { return }
                responseText += chunk

                // Parse the response to extract user-friendly text
                let userFriendlyText = parseUserFriendlyResponse(from: responseText)
                assistantMessage.text = userFriendlyText
                self.onMessageAdded?(assistantMessage) // Notify ViewModel of the chunk
            },
            onToolCall: { toolCall in
                receivedToolCall = toolCall
            }
        )

        // Streaming is complete, update the final message state
        assistantMessage.isStreaming = false
        print("[AGENT] Streaming complete, responseText length: \(responseText.count)")

        if let toolCall = receivedToolCall {
            // Tool call was received via callback. Create proposal from tool call.
            let proposal = ToolCallProposal(
                type: "tool_call",
                toolId: toolCall.function.name,
                requiresApproval: false, // Auto-approve for better UX
                input: parseFunctionArguments(toolCall.function.arguments),
                reason: "Tool execution requested by AI",
                nextStepAfterTool: "Continue with tool result"
            )

            // Update the assistant message to be more user-friendly
            let userFriendlyText = parseUserFriendlyResponse(from: responseText)
            assistantMessage.text = userFriendlyText.isEmpty ? "Using tools..." : userFriendlyText
            onMessageAdded?(assistantMessage)

            // Transition to proposing the tool (internal processing only)
            await transition(to: .toolProposed(proposal))

        } else if let proposal = parseToolCallProposal(from: responseText) {
            // Fallback: Tool call was proposed in text format
            let userFriendlyText = parseUserFriendlyResponse(from: responseText)
            assistantMessage.text = userFriendlyText.isEmpty ? "Using tools..." : userFriendlyText
            onMessageAdded?(assistantMessage)

            // Transition to proposing the tool (internal processing only)
            await transition(to: .toolProposed(proposal))

        } else {
            // Normal response. Send the final message content with user-friendly text.
            let userFriendlyText = parseUserFriendlyResponse(from: responseText)
            print("[AGENT] Normal response - original: '\(responseText)', parsed: '\(userFriendlyText)'")

            // If LLM provided a meaningful response, use it
            if !userFriendlyText.isEmpty || !responseText.isEmpty {
                assistantMessage.text = userFriendlyText.isEmpty ? responseText : userFriendlyText
                print("[AGENT] Setting assistant message text: '\(assistantMessage.text)'")
            } else if messages.contains(where: { $0.role == .tool }) {
                // LLM returned empty response after tool execution - this indicates LLM failed to process tool results
                // According to system prompt, LLM should always provide a response based on tool results
                // This is a fallback for when LLM doesn't follow the system prompt
                print("[AGENT] LLM failed to provide response after tool execution, using fallback summary")

                // Find the last tool result message and create a summary
                if let toolResultMessage = messages.last(where: { $0.role == .tool }) {
                    let summaryResponse = createToolSummaryResponse(toolResultMessage.text)
                    assistantMessage.text = summaryResponse
                    print("[AGENT] Using fallback summary response: '\(summaryResponse)'")
                } else {
                    assistantMessage.text = "ツールの実行が完了しました。"
                }
            } else {
                // No tool results and no response - this shouldn't happen with proper system prompt
                assistantMessage.text = "応答を生成できませんでした。"
                print("[AGENT] No response generated - this indicates a system prompt issue")
            }

            onMessageAdded?(assistantMessage)
            await transition(to: .completed)
        }
    }

    private func parseToolCallProposal(from text: String) -> ToolCallProposal? {
        // First, try to parse as OpenAI-style tool call format
        if let toolCall = parseOpenAIToolCall(from: text) {
            return ToolCallProposal(
                type: "tool_call",
                toolId: toolCall.function.name,
                requiresApproval: true, // Default to requiring approval
                input: parseFunctionArguments(toolCall.function.arguments),
                reason: "Tool execution requested",
                nextStepAfterTool: "Continue with tool result"
            )
        }

        // Try to extract JSON from backtick blocks or direct JSON
        var jsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```json") && jsonString.hasSuffix("```") {
            let startIndex = jsonString.index(jsonString.startIndex, offsetBy: 7)
            let endIndex = jsonString.index(jsonString.endIndex, offsetBy: -3)
            jsonString = String(jsonString[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if jsonString.hasPrefix("```") && jsonString.hasSuffix("```") {
            let startIndex = jsonString.index(jsonString.startIndex, offsetBy: 3)
            let endIndex = jsonString.index(jsonString.endIndex, offsetBy: -3)
            jsonString = String(jsonString[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try to parse the extracted/cleaned JSON
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String, type == "tool_call" else {
            print("[AGENT] Failed to parse tool call proposal from text: \(text.prefix(200))")
            return nil
        }

        return ToolCallProposal(
            type: type,
            toolId: json["tool_id"] as? String ?? "",
            requiresApproval: json["requires_approval"] as? Bool ?? true,
            input: json["input"] as? [String: Any] ?? [:],
            reason: json["reason"] as? String ?? "",
            nextStepAfterTool: json["next_step_after_tool"] as? String ?? ""
        )
    }

    /// Parses OpenAI-style tool call from response text
    private func parseOpenAIToolCall(from text: String) -> ToolCall? {
        // Look for tool call pattern in the text
        // This is a simplified parser - in production, you might want more robust parsing
        guard text.contains("\"tool_calls\"") || text.contains("tool_calls") else {
            return nil
        }

        // Try to extract tool call information from JSON response
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let toolCalls = json["tool_calls"] as? [[String: Any]],
           let firstToolCall = toolCalls.first,
           let id = firstToolCall["id"] as? String,
           let type = firstToolCall["type"] as? String,
           let function = firstToolCall["function"] as? [String: Any],
           let name = function["name"] as? String,
           let arguments = function["arguments"] as? String {

            return ToolCall(
                id: id,
                type: type,
                function: FunctionCall(name: name, arguments: arguments)
            )
        }

        return nil
    }

    /// Parses function arguments from JSON string
    private func parseFunctionArguments(_ arguments: String) -> [String: Any] {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    /// Parses the LLM response to extract user-friendly text, removing internal reasoning/thinking content.
    private func parseUserFriendlyResponse(from text: String) -> String {
        // First, check if the response contains <response> tags
        if let responseStart = text.range(of: "<response>"),
           let responseEnd = text.range(of: "</response>", range: responseStart.upperBound..<text.endIndex) {
            // Extract content between <response> tags
            let responseContent = text[responseStart.upperBound..<responseEnd.lowerBound]
            return String(responseContent).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If no <response> tags found, try to parse as JSON (structured response format)
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

            // Check if this is a tool call response - in that case, don't show the JSON
            if json["type"] as? String == "tool_call" {
                return ""
            }

            // Extract response field if it exists
            if let response = json["response"] as? String {
                return response
            }

            // Extract content field if it exists
            if let content = json["content"] as? String {
                return content
            }

            // Extract message field if it exists
            if let message = json["message"] as? String {
                return message
            }
        }

        // If not JSON or no structured fields found, try to extract text before any JSON
        if let jsonStart = text.firstIndex(of: "{"), jsonStart != text.startIndex {
            let beforeJson = text[..<jsonStart].trimmingCharacters(in: .whitespacesAndNewlines)
            if !beforeJson.isEmpty {
                return beforeJson
            }
        }

        // If no structured response found, try to remove common thinking patterns
        var cleanedText = text

        // Remove content between <thinking> tags
        if let thinkingStart = cleanedText.range(of: "<thinking>"),
           let thinkingEnd = cleanedText.range(of: "</thinking>", range: thinkingStart.upperBound..<cleanedText.endIndex) {
            cleanedText.removeSubrange(thinkingStart.lowerBound..<thinkingEnd.upperBound)
        }

        // Remove content between ```thinking blocks
        if let thinkingBlockStart = cleanedText.range(of: "```thinking"),
           let thinkingBlockEnd = cleanedText.range(of: "```", range: thinkingBlockStart.upperBound..<cleanedText.endIndex) {
            cleanedText.removeSubrange(thinkingBlockStart.lowerBound..<thinkingBlockEnd.upperBound)
        }

        // Remove content between <IMPORTANT> tags
        if let importantStart = cleanedText.range(of: "<IMPORTANT>"),
           let importantEnd = cleanedText.range(of: "</IMPORTANT>", range: importantStart.upperBound..<cleanedText.endIndex) {
            cleanedText.removeSubrange(importantStart.lowerBound..<importantEnd.upperBound)
        }

        // Remove lines that start with specific internal markers
        let lines = cleanedText.components(separatedBy: .newlines)
        let filteredLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.hasPrefix("<IMPORTANT>") &&
                   !trimmed.hasPrefix("I'm now in") &&
                   !trimmed.hasPrefix("When I need to use a tool") &&
                   !trimmed.contains("tool_call JSON") &&
                   !trimmed.contains("requires_approval")
        }
        cleanedText = filteredLines.joined(separator: "\n")

        // Clean up extra whitespace
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove multiple consecutive newlines
        while cleanedText.contains("\n\n\n") {
            cleanedText = cleanedText.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // If the cleaned text is empty or still contains JSON, return empty string
        if cleanedText.isEmpty || cleanedText.hasPrefix("{") || cleanedText.hasSuffix("}") {
            return ""
        }

        return cleanedText
    }

    private func needsApproval(for proposal: ToolCallProposal) -> Bool {
        // First check if the tool has auto-approval enabled
        if let tool = ToolRegistry.shared.tool(forName: proposal.toolId), tool.autoApproval {
            print("[AGENT] No approval needed: tool '\(proposal.toolId)' has autoApproval enabled")
            return false
        }

        if toolCallCount >= config.maxToolCallsPerRun {
            print("[AGENT] Needs approval: tool call count limit reached (\(toolCallCount) >= \(config.maxToolCallsPerRun))")
            return true // Force approval
        }

        switch config.approvalMode {
        case .alwaysAsk:
            print("[AGENT] Needs approval: approvalMode is .alwaysAsk")
            return true
        case .perThread:
            let needs = !threadGrant
            print("[AGENT] Needs approval: approvalMode is .perThread, threadGrant=\(threadGrant), needs=\(needs)")
            return needs
        case .autoApprove:
            print("[AGENT] No approval needed: approvalMode is .autoApprove")
            return false
        }
    }

    private func executeTool(_ proposal: ToolCallProposal) async throws {
        toolCallCount += 1
        print("[TOOL] Executing: \(proposal.toolId)")
        print("[TOOL] Input: \(proposal.input)")

        // Create ToolCall from proposal
        let argumentsData = try JSONSerialization.data(withJSONObject: proposal.input, options: [])
        let argumentsString = String(data: argumentsData, encoding: .utf8) ?? "{}"
        let function = FunctionCall(name: proposal.toolId, arguments: argumentsString)
        let toolCall = ToolCall(id: UUID().uuidString, type: "function", function: function)

        print("[TOOL] Created ToolCall: \(toolCall.function.name)")

        do {
            print("[TOOL] Calling executor...")
            let result = try await toolExecutor.executeToolCall(toolCall)
            print("[TOOL] Executor returned result, length: \(result.count)")

            // Add tool result message
            let toolResultMessage = ChatMessage(role: .tool, text: result, toolCallId: toolCall.id)
            messages.append(toolResultMessage)
            print("[TOOL] Added result message to conversation")

            print("[TOOL] Transitioning to awaitingLLM...")
            await transition(to: .awaitingLLM)
            print("[TOOL] Transition complete")
        } catch {
            print("[TOOL] Executor failed: \(error.localizedDescription)")
            await transition(to: .failed(error.localizedDescription))
        }
    }

    /// Creates a user-friendly summary response based on tool results
    private func createToolSummaryResponse(_ toolResult: String) -> String {
        // For Google Search results, create a natural summary
        if toolResult.hasPrefix("🔍 **Search Results:**") {
            // Extract key information from search results and create a natural response
            let lines = toolResult.components(separatedBy: "\n")
            var summary = "検索結果を見つけました：\n\n"

            var currentItem = 0
            for line in lines {
                if line.hasPrefix("1. **") || line.hasPrefix("2. **") || line.hasPrefix("3. **") ||
                   line.hasPrefix("4. **") || line.hasPrefix("5. **") {
                    currentItem += 1
                    if currentItem <= 3 { // Limit to top 3 results for brevity
                        let cleanLine = line.replacingOccurrences(of: "**", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        summary += "• \(cleanLine)\n"
                    }
                }
            }

            if currentItem > 3 {
                summary += "\n... 他にも\(currentItem - 3)件の結果があります。"
            }

            return summary
        }

        // For other tools, create appropriate summaries
        if toolResult.contains("success") || toolResult.contains("Success") {
            return "操作が正常に完了しました。"
        } else if toolResult.contains("error") || toolResult.contains("Error") {
            return "操作中にエラーが発生しました。詳細はログをご確認ください。"
        } else {
            // Generic fallback for other tool results
            return "ツールの実行が完了しました。結果：\(toolResult.prefix(200))\(toolResult.count > 200 ? "..." : "")"
        }
    }

    /// Formats tool result as a user-friendly assistant response (legacy method)
    private func formatToolResultAsResponse(_ toolResult: String) -> String {
        return createToolSummaryResponse(toolResult)
    }

    private func transition(to newState: AgentState) async {
        state = newState
        onStateChange?(newState)
    }
}
