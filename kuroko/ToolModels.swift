import Foundation

// MARK: - Tool Definitions for Request

struct Tool: Codable {
    let type: String
    let function: FunctionDefinition
}

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: ParameterDefinition
}

struct ParameterDefinition: Codable {
    let type: String
    let properties: [String: PropertyDefinition]
    let required: [String]
}

struct PropertyDefinition: Codable {
    let type: String
    let description: String
}

// MARK: - Tool Calls in Response

struct ToolCall: Codable, Equatable {
    let id: String
    let type: String
    let function: FunctionCall
}

struct FunctionCall: Codable, Equatable {
    let name: String
    let arguments: String
}

// MARK: - Tool Output for Response

struct ToolMessage: Codable {
    let role: String
    let content: String
    let tool_call_id: String
    
    // Custom coding keys might not be needed if decoding manually or matching API exactly
}
