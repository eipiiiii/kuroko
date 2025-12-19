// MARK: - Agent Runner Models

/// Represents the mode of operation (Act mode only).
public enum OperationMode: String, Codable {
    case act
}

/// Represents the state of the agent runner.
public enum AgentState {
    case idle
    case awaitingLLM
    case toolProposed(ToolCallProposal)
    case awaitingApproval(ToolCallProposal)
    case executingTool(ToolCallProposal)
    case completed
    case failed(String) // Store error message instead of Error
}

/// Represents a tool call proposal from the LLM.
public struct ToolCallProposal {
    public let type: String // "tool_call"
    public let toolId: String
    public let requiresApproval: Bool
    public let input: [String: Any]
    public let reason: String
    public let nextStepAfterTool: String

    public init(type: String = "tool_call", toolId: String, requiresApproval: Bool, input: [String: Any], reason: String, nextStepAfterTool: String) {
        self.type = type
        self.toolId = toolId
        self.requiresApproval = requiresApproval
        self.input = input
        self.reason = reason
        self.nextStepAfterTool = nextStepAfterTool
    }
}

/// Approval mode for tool calls.
public enum ApprovalMode: String, Codable {
    case alwaysAsk
    case perThread
    case autoApprove
}

/// Configuration for the agent runner.
public struct AgentConfig {
    public let approvalMode: ApprovalMode
    public let maxToolCallsPerRun: Int

    public init(approvalMode: ApprovalMode = .alwaysAsk, maxToolCallsPerRun: Int = 10) {
        self.approvalMode = approvalMode
        self.maxToolCallsPerRun = maxToolCallsPerRun
    }
}
