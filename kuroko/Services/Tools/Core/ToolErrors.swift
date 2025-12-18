import Foundation

// MARK: - Tool Errors

/// Defines errors that can occur during tool execution.
public enum ToolError: LocalizedError {
    case toolNotFound(String)
    case argumentEncodingError
    case invalidJSONStructure
    case invalidArguments(toolName: String, details: String)
    case missingRequiredParameter(String)
    case executionFailed(String)
    case toolDisabled(String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool not found: '\(name)'"
        case .argumentEncodingError:
            return "Tool arguments are not valid UTF-8 encoded strings."
        case .invalidJSONStructure:
            return "Tool arguments are not a valid JSON object."
        case .invalidArguments(let toolName, let details):
            return "Invalid arguments for tool '\(toolName)': \(details)"
        case .missingRequiredParameter(let param):
            return "Missing required parameter: '\(param)'"
        case .executionFailed(let reason):
            return "Tool execution failed: \(reason)"
        case .toolDisabled(let name):
            return "Tool '\(name)' is currently disabled."
        }
    }
}
