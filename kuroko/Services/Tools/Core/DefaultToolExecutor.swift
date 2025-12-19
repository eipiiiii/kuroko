import Foundation

// MARK: - Default Tool Executor

/// The default implementation of the ToolExecutor protocol.
public class DefaultToolExecutor: ToolExecutor {
    
    private let toolRegistry: ToolRegistry
    
    public init(toolRegistry: ToolRegistry = .shared) {
        self.toolRegistry = toolRegistry
    }
    
    public func executeToolCall(_ toolCall: ToolCall) async throws -> String {
        let functionName = toolCall.function.name
        
        guard let tool = toolRegistry.tool(forName: functionName) else {
            throw ToolError.toolNotFound(functionName)
        }
        
        guard tool.isEnabled else {
            throw ToolError.toolDisabled(functionName)
        }
        
        let argsDict: [String: Any]
        do {
            argsDict = try parseArguments(toolCall.function.arguments)
        } catch {
            throw ToolError.invalidArguments(toolName: functionName, details: error.localizedDescription)
        }
        
        print("🔧 Executing tool: \(functionName) with arguments: \(argsDict)")

        let result = try await tool.execute(arguments: argsDict)
        print("🔧 Tool \(functionName) returned result (length: \(result.count)): \(result)")

        return result
    }
    
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
