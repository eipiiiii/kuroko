import Foundation

// MARK: - Tool Definition

/// A protocol that defines a tool that can be executed by the AI.
public protocol Tool {
    /// The name of the tool, matching the function name used in the LLM's tool-calling request.
    var name: String { get }
    
    /// A description of what the tool does, for the LLM to understand its purpose.
    var description: String { get }
    
    /// The JSON schema for the tool's parameters.
    var parameters: [String: Any] { get }
    
    /// Executes the tool with the given arguments.
    /// - Parameter arguments: A dictionary of arguments, parsed from the LLM's request.
    /// - Returns: A string result to be sent back to the LLM.
    func execute(arguments: [String: Any]) async throws -> String
}

// Extension to provide the full tool definition for the LLM API
public extension Tool {
    /// The complete tool definition as a dictionary for use with LLM APIs.
    var definition: [String: Any] {
        return [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        ]
    }
}

// MARK: - Tool Executor

/// A protocol for a service that executes tool calls.
public protocol ToolExecutor {
    /// Executes a given tool call.
    /// - Parameter toolCall: The tool call request from the LLM.
    /// - Returns: The string result of the tool's execution.
    func executeToolCall(_ toolCall: ToolCall) async throws -> String
}
