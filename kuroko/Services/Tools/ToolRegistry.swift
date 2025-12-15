import Foundation

// MARK: - Tool Registry

/// A singleton service that manages the availability and execution of all tools.
public class ToolRegistry {
    
    public static let shared = ToolRegistry()
    
    private let configService: KurokoConfigurationService
    private let searchService: SearchService
    // Add other dependencies like FileSystemService if needed by tools
    
    /// A list of all possible tools in the application.
    private let allTools: [Tool]
    
    private init(
        configService: KurokoConfigurationService = .shared,
        searchService: SearchService = .shared
    ) {
        self.configService = configService
        self.searchService = searchService
        
        // Initialize all tool implementations here
        self.allTools = [
            GoogleSearchTool(searchService: searchService, configService: configService)
            // Future tools like FileSystem tools would be initialized and added here.
        ]
    }
    
    /// Retrieves the specific tool instance by its name.
    /// - Parameter name: The name of the tool.
    /// - Returns: An optional `Tool` instance.
    func tool(forName name: String) -> Tool? {
        return allTools.first { $0.name == name }
    }
    
    /// Returns a list of tools that are currently available based on app configuration.
    /// For example, Google Search is only available if the API key is set.
    func getAvailableTools() -> [Tool] {
        var availableTools: [Tool] = []
        
        // Check for Google Search tool availability
        if !configService.googleSearchApiKey.isEmpty && !configService.googleSearchEngineId.isEmpty {
            if let googleSearchTool = tool(forName: "google_search") {
                availableTools.append(googleSearchTool)
            }
        }
        
        // Check for File System tools availability
        // let fileAccessManager = FileAccessManager.shared
        // if fileAccessManager.workingDirectoryURL != nil {
        //     // Add file system tools...
        // }
        
        return availableTools
    }
}

// MARK: - Concrete Tool Implementations

/// The tool for performing a Google search.
struct GoogleSearchTool: Tool {
    let name = "google_search"
    let description = "Search Google for information when you cannot answer from your knowledge base or need up-to-date information."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "query": [
                "type": "string",
                "description": "The search query to send to Google."
            ]
        ],
        "required": ["query"]
    ]
    
    private let searchService: SearchService
    private let configService: KurokoConfigurationService
    
    init(searchService: SearchService, configService: KurokoConfigurationService) {
        self.searchService = searchService
        self.configService = configService
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // This should align with the error modeling in the new ToolExecutor
            throw NSError(domain: "ToolError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing required parameter: query"])
        }
        
        return try await searchService.performSearch(
            query: query,
            apiKey: configService.googleSearchApiKey,
            engineId: configService.googleSearchEngineId
        )
    }
}
