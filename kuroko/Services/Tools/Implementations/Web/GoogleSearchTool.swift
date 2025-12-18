import Foundation

/// Tool for performing a Google search.
class GoogleSearchTool: Tool {
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
    
    var isEnabled: Bool = true
    
    private let searchService: SearchService
    private let configService: KurokoConfigurationService
    
    init(searchService: SearchService, configService: KurokoConfigurationService) {
        self.searchService = searchService
        self.configService = configService
    }
    
    func execute(arguments: [String: Any]) async throws -> String {
        guard let query = arguments["query"] as? String, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ToolError.missingRequiredParameter("query")
        }
        
        return try await searchService.performSearch(
            query: query,
            apiKey: configService.googleSearchApiKey,
            engineId: configService.googleSearchEngineId
        )
    }
}
