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

        // Start with planning phase for complex tasks
        await transition(to: .planning(nil))
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
            case .planning(let existingPlan):
                try await generatePlan(existingPlan)

            case .awaitingPlanApproval:
                return // Wait for user approval

            case .executingPlan(let plan, let currentStep):
                try await executePlanStep(plan, stepIndex: currentStep)

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

            case .reflecting(let result):
                try await reflectOnExecution(result)

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

    /// Parses the LLM response to extract user-friendly text and preserve thinking process in conversation history.
    private func parseUserFriendlyResponse(from text: String) -> String {
        var remainingText = text

        // Extract and preserve thinking process
        if let thinkingStart = remainingText.range(of: "<thinking>"),
           let thinkingEnd = remainingText.range(of: "</thinking>", range: thinkingStart.upperBound..<remainingText.endIndex) {
            let thinkingContent = remainingText[thinkingStart.upperBound..<thinkingEnd.lowerBound]

            // Add thinking as a separate assistant message
            let thinkingMessage = ChatMessage(
                role: .assistant,
                text: "**思考プロセス:**\n\(String(thinkingContent).trimmingCharacters(in: .whitespacesAndNewlines))"
            )
            messages.append(thinkingMessage)
            onMessageAdded?(thinkingMessage)

            // Remove thinking section from remaining text
            remainingText.removeSubrange(thinkingStart.lowerBound..<thinkingEnd.upperBound)
        }

        // Extract and preserve observation process
        if let observationStart = remainingText.range(of: "<observation>"),
           let observationEnd = remainingText.range(of: "</observation>", range: observationStart.upperBound..<remainingText.endIndex) {
            let observationContent = remainingText[observationStart.upperBound..<observationEnd.lowerBound]

            // Add observation as a separate assistant message
            let observationMessage = ChatMessage(
                role: .assistant,
                text: "**分析結果:**\n\(String(observationContent).trimmingCharacters(in: .whitespacesAndNewlines))"
            )
            messages.append(observationMessage)
            onMessageAdded?(observationMessage)

            // Remove observation section from remaining text
            remainingText.removeSubrange(observationStart.lowerBound..<observationEnd.upperBound)
        }

        // Extract and preserve reflection process
        if let reflectionStart = remainingText.range(of: "<reflection>"),
           let reflectionEnd = remainingText.range(of: "</reflection>", range: reflectionStart.upperBound..<remainingText.endIndex) {
            let reflectionContent = remainingText[reflectionStart.upperBound..<reflectionEnd.lowerBound]

            // Add reflection as a separate assistant message
            let reflectionMessage = ChatMessage(
                role: .assistant,
                text: "**振り返り:**\n\(String(reflectionContent).trimmingCharacters(in: .whitespacesAndNewlines))"
            )
            messages.append(reflectionMessage)
            onMessageAdded?(reflectionMessage)

            // Remove reflection section from remaining text
            remainingText.removeSubrange(reflectionStart.lowerBound..<reflectionEnd.upperBound)
        }

        // First, check if the response contains <response> tags
        if let responseStart = remainingText.range(of: "<response>"),
           let responseEnd = remainingText.range(of: "</response>", range: responseStart.upperBound..<remainingText.endIndex) {
            // Extract content between <response> tags
            let responseContent = remainingText[responseStart.upperBound..<responseEnd.lowerBound]
            return String(responseContent).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If no <response> tags found, try to parse as JSON (structured response format)
        if let data = remainingText.data(using: .utf8),
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
        if let jsonStart = remainingText.firstIndex(of: "{"), jsonStart != remainingText.startIndex {
            let beforeJson = remainingText[..<jsonStart].trimmingCharacters(in: .whitespacesAndNewlines)
            if !beforeJson.isEmpty {
                return beforeJson
            }
        }

        // If no structured response found, try to remove common thinking patterns (legacy support)
        var cleanedText = remainingText

        // Remove content between ```thinking blocks (legacy)
        if let thinkingBlockStart = cleanedText.range(of: "```thinking"),
           let thinkingBlockEnd = cleanedText.range(of: "```", range: thinkingBlockStart.upperBound..<cleanedText.endIndex) {
            cleanedText.removeSubrange(thinkingBlockStart.lowerBound..<thinkingBlockEnd.upperBound)
        }

        // Remove content between <IMPORTANT> tags (legacy)
        if let importantStart = cleanedText.range(of: "<IMPORTANT>"),
           let importantEnd = cleanedText.range(of: "</IMPORTANT>", range: importantStart.upperBound..<cleanedText.endIndex) {
            cleanedText.removeSubrange(importantStart.lowerBound..<importantEnd.upperBound)
        }

        // Remove lines that start with specific internal markers (legacy)
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

    // MARK: - Plan-Act Architecture Methods

    /// Generates a task execution plan using LLM
    private func generatePlan(_ existingPlan: TaskPlan?) async throws {
        print("[PLAN] Generating execution plan...")

        // Get the last user message
        guard let userMessage = messages.last(where: { $0.role == .user }) else {
            throw AgentError.noUserMessage
        }

        let planPrompt = """
以下のタスクを実行するための計画を作成してください：

タスク: \(userMessage.text)

利用可能なツール:
- FileSystemTools: ファイル操作（読み取り、書き込み、検索）
- AppleCalendarTool: カレンダー操作
- AppleRemindersTool: リマインダー操作
- GoogleSearchTool: ウェブ検索

計画の形式（JSON）:
{
  "steps": [
    {
      "description": "ステップの説明",
      "toolsRequired": ["使用するツール名"],
      "expectedOutcome": "期待される結果",
      "dependencies": ["依存する他のステップのID"],
      "estimatedDuration": 所要時間（秒）
    }
  ],
  "estimatedDuration": 全体の所要時間,
  "riskAssessment": "low|medium|high|critical"
}

シンプルなタスクの場合は直接実行し、複雑なタスクのみ計画を作成してください。
"""

        let config = LLMConfig(model: KurokoConfigurationService.shared.selectedModel)
        var planResponse = ""

        try await llmService.sendMessage(
            message: planPrompt,
            history: messages.dropLast(), // Exclude current planning context
            config: config,
            onChunk: { chunk in
                planResponse += chunk
            },
            onToolCall: { _ in } // Ignore tool calls during planning
        )

        // Parse the plan from LLM response
        if let plan = parseTaskPlan(from: planResponse) {
            print("[PLAN] Plan generated with \(plan.steps.count) steps")
            await transition(to: .awaitingPlanApproval(plan))
        } else {
            // If plan parsing fails, fall back to direct execution
            print("[PLAN] Plan parsing failed, falling back to direct execution")
            await transition(to: .awaitingLLM)
        }
    }

    /// Executes a specific step in the task plan
    private func executePlanStep(_ plan: TaskPlan, stepIndex: Int) async throws {
        guard stepIndex < plan.steps.count else {
            // All steps completed, move to reflection
            let executionResult = createExecutionResult(from: plan)
            await transition(to: .reflecting(executionResult))
            return
        }

        let step = plan.steps[stepIndex]
        print("[PLAN] Executing step \(stepIndex + 1)/\(plan.steps.count): \(step.description)")

        // Add step execution message
        let stepMessage = ChatMessage(
            role: .assistant,
            text: "ステップ \(stepIndex + 1): \(step.description)"
        )
        messages.append(stepMessage)
        onMessageAdded?(stepMessage)

        // For now, delegate to LLM for step execution
        // In future phases, this could be more sophisticated
        await transition(to: .awaitingLLM)

        // Note: After LLM processes this step, it should transition back to executingPlan
        // with incremented step index. This logic will be implemented in callLLM method.
    }

    /// Performs reflection on task execution
    private func reflectOnExecution(_ result: ExecutionResult) async throws {
        print("[REFLECT] Analyzing execution result...")

        let reflectionPrompt = """
以下のタスク実行を振り返り、改善点を分析してください：

タスク: \(result.originalTask)
実行時間: \(result.duration)秒
成功: \(result.success)

実行ステップ:
\(result.steps.enumerated().map { "ステップ \($0.offset + 1): \($0.element.description)" }.joined(separator: "\n"))

改善点を以下の観点から分析してください：
1. 効率性: より良い方法はあったか
2. 完全性: 必要なステップがすべて実行されたか
3. 安全性: リスクは適切に管理されたか
4. 学習点: 次回同様のタスクで活かせること

分析結果を簡潔にまとめてください。
"""

        let config = LLMConfig(model: KurokoConfigurationService.shared.selectedModel)
        var reflectionResponse = ""

        try await llmService.sendMessage(
            message: reflectionPrompt,
            history: messages,
            config: config,
            onChunk: { chunk in
                reflectionResponse += chunk
            },
            onToolCall: { _ in }
        )

        // Add reflection result to conversation
        let reflectionMessage = ChatMessage(
            role: .assistant,
            text: "実行の振り返り:\n\(reflectionResponse)"
        )
        messages.append(reflectionMessage)
        onMessageAdded?(reflectionMessage)

        // Complete the task
        await transition(to: .completed)
    }

    // MARK: - Helper Methods

    /// Parses task plan from LLM response
    private func parseTaskPlan(from response: String) -> TaskPlan? {
        // Try to extract JSON from response
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}"),
              jsonStart < jsonEnd else {
            return nil
        }

        let jsonString = String(response[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Parse steps
        guard let stepsJson = json["steps"] as? [[String: Any]] else { return nil }

        let steps = stepsJson.compactMap { stepJson -> PlanStep? in
            guard let description = stepJson["description"] as? String else { return nil }
            let toolsRequired = stepJson["toolsRequired"] as? [String] ?? []
            let expectedOutcome = stepJson["expectedOutcome"] as? String ?? ""
            let dependencies = (stepJson["dependencies"] as? [String])?.compactMap { UUID(uuidString: $0) } ?? []
            let estimatedDuration = stepJson["estimatedDuration"] as? TimeInterval ?? 0

            return PlanStep(
                description: description,
                toolsRequired: toolsRequired,
                expectedOutcome: expectedOutcome,
                dependencies: dependencies,
                estimatedDuration: estimatedDuration
            )
        }

        let estimatedDuration = json["estimatedDuration"] as? TimeInterval ?? 0
        let riskAssessmentString = json["riskAssessment"] as? String ?? "medium"
        let riskAssessment = RiskLevel(rawValue: riskAssessmentString) ?? .medium

        return TaskPlan(steps: steps, estimatedDuration: estimatedDuration, riskAssessment: riskAssessment)
    }

    /// Creates execution result from completed plan
    private func createExecutionResult(from plan: TaskPlan) -> ExecutionResult {
        // Get the original task
        let originalTask = messages.first(where: { $0.role == .user })?.text ?? "Unknown task"

        // Create execution steps from plan steps (simplified)
        let executionSteps = plan.steps.map { step in
            ExecutionStep(
                description: step.description,
                success: true, // Assume success for now
                duration: step.estimatedDuration
            )
        }

        return ExecutionResult(
            originalTask: originalTask,
            steps: executionSteps,
            success: true,
            duration: plan.estimatedDuration
        )
    }
}

// MARK: - Errors
enum AgentError: Error {
    case noUserMessage
    case invalidPlanFormat
    case planExecutionFailed
}
