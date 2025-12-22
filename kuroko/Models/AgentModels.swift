// MARK: - Agent Runner Models

import Foundation

/// Represents the mode of operation (Act mode only).
public enum OperationMode: String, Codable {
    case act
}

/// Represents the state of the agent runner.
public enum AgentState {
    case idle
    case planning(TaskPlan?)  // 計画立案中 (オプションで既存計画)
    case awaitingPlanApproval(TaskPlan) // 計画承認待ち
    case executingPlan(TaskPlan, currentStep: Int) // 計画実行中
    case awaitingLLM
    case toolProposed(ToolCallProposal)
    case awaitingApproval(ToolCallProposal)
    case executingTool(ToolCallProposal) // 実行状態を追加
    case reflecting(ExecutionResult) // 実行結果の振り返り
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

// MARK: - Plan-Act Architecture Models

/// Represents a task execution plan.
public struct TaskPlan: Codable, Identifiable {
    public let id: UUID
    public let steps: [PlanStep]
    public let estimatedDuration: TimeInterval
    public let riskAssessment: RiskLevel
    public let alternativePlans: [TaskPlan]?
    public let createdAt: Date

    public init(steps: [PlanStep], estimatedDuration: TimeInterval = 0, riskAssessment: RiskLevel = .medium, alternativePlans: [TaskPlan]? = nil) {
        self.id = UUID()
        self.steps = steps
        self.estimatedDuration = estimatedDuration
        self.riskAssessment = riskAssessment
        self.alternativePlans = alternativePlans
        self.createdAt = Date()
    }
}

/// Represents a single step in a task plan.
public struct PlanStep: Codable, Identifiable {
    public let id: UUID
    public let description: String
    public let toolsRequired: [String]
    public let expectedOutcome: String
    public let dependencies: [UUID] // 他のステップのID
    public let estimatedDuration: TimeInterval

    public init(description: String, toolsRequired: [String] = [], expectedOutcome: String = "", dependencies: [UUID] = [], estimatedDuration: TimeInterval = 0) {
        self.id = UUID()
        self.description = description
        self.toolsRequired = toolsRequired
        self.expectedOutcome = expectedOutcome
        self.dependencies = dependencies
        self.estimatedDuration = estimatedDuration
    }
}

/// Risk level assessment for task plans.
public enum RiskLevel: String, Codable {
    case low
    case medium
    case high
    case critical
}

// MARK: - Tool Execution State Models

/// Represents the execution phase of a tool
public enum ToolExecutionPhase: String, Codable {
    case starting
    case executing
    case processingResult
    case completed
    case failed
}

/// Represents the type of tool being executed
public enum ToolType: String, Codable {
    case fileOperation
    case search
    case codeExecution
    case web
    case other
}

/// Represents detailed execution state of a tool
public struct ToolExecutionState: Identifiable, Codable {
    public let id: UUID
    public let toolName: String
    public let toolType: ToolType
    public var phase: ToolExecutionPhase
    public var progress: Double
    public var currentStep: String?
    public var estimatedTimeRemaining: TimeInterval?
    public var startedAt: Date
    public var finishedAt: Date?
    public var metadata: [String: String]  // filePath, searchQuery, command など
    public var error: ToolErrorInfo?

    public init(
        id: UUID = UUID(),
        toolName: String,
        toolType: ToolType,
        phase: ToolExecutionPhase = .starting,
        progress: Double = 0.0,
        currentStep: String? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        startedAt: Date = Date(),
        finishedAt: Date? = nil,
        metadata: [String: String] = [:],
        error: ToolErrorInfo? = nil
    ) {
        self.id = id
        self.toolName = toolName
        self.toolType = toolType
        self.phase = phase
        self.progress = progress
        self.currentStep = currentStep
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.metadata = metadata
        self.error = error
    }

    /// Calculates execution duration
    public var executionDuration: TimeInterval? {
        guard let finishedAt = finishedAt else { return nil }
        return finishedAt.timeIntervalSince(startedAt)
    }
}

/// Represents error information for tool execution
public struct ToolErrorInfo: Codable {
    public let message: String
    public let code: String?
    public let category: String?  // network, validation, execution, timeout など
    public let debugDetails: String?

    public init(message: String, code: String? = nil, category: String? = nil, debugDetails: String? = nil) {
        self.message = message
        self.code = code
        self.category = category
        self.debugDetails = debugDetails
    }
}

/// Represents the result of a task execution.
public struct ExecutionResult: Codable {
    public let originalTask: String
    public let steps: [ExecutionStep]
    public let success: Bool
    public let duration: TimeInterval
    public let errorMessage: String?
    public let insights: [String]

    public init(originalTask: String, steps: [ExecutionStep] = [], success: Bool = false, duration: TimeInterval = 0, errorMessage: String? = nil, insights: [String] = []) {
        self.originalTask = originalTask
        self.steps = steps
        self.success = success
        self.duration = duration
        self.errorMessage = errorMessage
        self.insights = insights
    }
}

/// Represents a single execution step result.
public struct ExecutionStep: Codable {
    public let description: String
    public let toolUsed: String?
    public let success: Bool
    public let duration: TimeInterval
    public let output: String?
    public let error: String?

    public init(description: String, toolUsed: String? = nil, success: Bool = false, duration: TimeInterval = 0, output: String? = nil, error: String? = nil) {
        self.description = description
        self.toolUsed = toolUsed
        self.success = success
        self.duration = duration
        self.output = output
        self.error = error
    }
}

// MARK: - Tool Result Models

/// Represents the result of any tool execution
public enum AnyToolResult {
    case fileOperation(FileOperationUIResult)
    case search(SearchResult)
    case codeExecution(CodeExecutionResult)
    case raw(String)
}

/// File operation result for UI display
public struct FileOperationUIResult: Codable {
    public let operation: FileOperationUIType
    public let filePath: String?
    public let content: String?
    public let diff: DiffModel?

    public enum FileOperationUIType: String, Codable {
        case read
        case write
        case edit
        case delete
        case list
    }
}

/// Diff model for file changes
public struct DiffModel: Codable {
    public let filePath: String
    public let hunks: [DiffHunk]

    public struct DiffHunk: Codable, Hashable {
        public let oldStart: Int
        public let oldLines: Int
        public let newStart: Int
        public let newLines: Int
        public let lines: [String]
    }
}

/// Search result
public struct SearchResult: Codable {
    public let query: String
    public let matches: [SearchMatch]

    public struct SearchMatch: Codable {
        public let fileOrUrl: String
        public let lineNumber: Int?
        public let text: String
        public let ranges: [RangeInfo]

        public struct RangeInfo: Codable {
            public let start: Int
            public let end: Int
        }
    }
}

/// Code execution result
public struct CodeExecutionResult: Codable {
    public let command: String
    public let stdout: String
    public let stderr: String
    public let exitCode: Int
}
