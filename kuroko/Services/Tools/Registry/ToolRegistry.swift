import Foundation

// MARK: - Tool Registry

/// A singleton service that manages the availability and execution of all tools.
public class ToolRegistry {
    
    public static let shared = ToolRegistry()
    
    private let configService: KurokoConfigurationService
    private let searchService: SearchService
    
    /// A list of all possible tools in the application.
    private var allTools: [Tool] = []
    
    private init(
        configService: KurokoConfigurationService = .shared,
        searchService: SearchService = .shared
    ) {
        self.configService = configService
        self.searchService = searchService
        
        registerDefaultTools()
    }
    
    private func registerDefaultTools() {
        // Register default tools
        register(tool: GoogleSearchTool(searchService: searchService, configService: configService))
        
        // File System Tools
        register(tool: ListDirectoryTool())
        register(tool: ReadFileTool())
        register(tool: CreateFileTool())
        register(tool: WriteFileTool())
        register(tool: SearchFilesTool())
    }
    
    /// Registers a new tool.
    /// - Parameter tool: The tool to register.
    public func register(tool: Tool) {
        // Avoid duplicate registration
        if !allTools.contains(where: { $0.name == tool.name }) {
            allTools.append(tool)
        }
    }
    
    /// Retrieves the specific tool instance by its name.
    /// - Parameter name: The name of the tool.
    /// - Returns: An optional `Tool` instance.
    func tool(forName name: String) -> Tool? {
        return allTools.first { $0.name == name }
    }
    
    /// Returns a list of tools that are currently available based on app configuration and enabled status.
    func getAvailableTools() -> [Tool] {
        return allTools.filter { tool in
            // First check if explicitly enabled
            guard tool.isEnabled else { return false }
            
            // Check specific requirements for certain tools
            if tool.name == "google_search" {
                return !configService.googleSearchApiKey.isEmpty && !configService.googleSearchEngineId.isEmpty
            }
            
            // File system tools require a working directory
            if ["list_directory", "read_file", "create_file", "write_file", "search_files"].contains(tool.name) {
                return FileAccessManager.shared.workingDirectoryURL != nil
            }
            
            return true
        }
    }
    
    /// Toggles the enabled state of a tool
    func setToolEnabled(_ name: String, enabled: Bool) {
        if let tool = tool(forName: name) {
            tool.isEnabled = enabled
        }
    }
}
