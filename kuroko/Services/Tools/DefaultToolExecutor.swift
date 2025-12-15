import Foundation

// MARK: - Default Tool Executor

/// The default implementation of the ToolExecutor protocol.
/// This class is responsible for parsing tool calls, finding the appropriate tool
/// in the registry, and executing it.
public class DefaultToolExecutor: ToolExecutor {
    
    private let toolRegistry: ToolRegistry
    
    public init(toolRegistry: ToolRegistry = .shared) {
        self.toolRegistry = toolRegistry
    }
    
    /// Executes a given tool call.
    /// This method finds the tool in the registry, validates and parses its arguments,
    /// and then executes the tool.
    public func executeToolCall(_ toolCall: ToolCall) async throws -> String {
        let functionName = toolCall.function.name
        
        // Find the tool in the registry.
        guard let tool = toolRegistry.tool(forName: functionName) else {
            throw ToolError.toolNotFound(functionName)
        }
        
        // Validate and parse arguments.
        let argsDict: [String: Any]
        do {
            argsDict = try parseArguments(toolCall.function.arguments)
        } catch {
            throw ToolError.invalidArguments(toolName: functionName, details: error.localizedDescription)
        }
        
        print("🔧 Executing tool: \(functionName) with arguments: \(argsDict)")
        
        // Execute the tool.
        return try await tool.execute(arguments: argsDict)
    }
    
    /// Parses the JSON string of arguments into a dictionary.
    private func parseArguments(_ argumentsString: String) throws -> [String: Any] {
        guard let argsData = argumentsString.data(using: .utf8) else {
            throw ToolError.argumentEncodingError
        }
        
        guard let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            throw ToolError.invalidJSONStructure
        }
        
        return argsDict
    }
}

// MARK: - Tool Errors

/// Defines errors that can occur during tool execution.
enum ToolError: LocalizedError {
    case toolNotFound(String)
    case argumentEncodingError
    case invalidJSONStructure
    case invalidArguments(toolName: String, details: String)
    case missingRequiredParameter(String)
    case executionFailed(String)

    var errorDescription: String? {
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
        }
    }
}