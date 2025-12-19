import Foundation

/// Tool for listing files and directories.
class ListDirectoryTool: Tool {
    let name = "list_directory"
    let description = "List files and directories in the specified directory within the working directory."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "path": [
                "type": "string",
                "description": "The relative path of the directory to list. Defaults to current directory ('.') if not specified.",
                "default": "."
            ]
        ]
    ]
    
    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        let path = arguments["path"] as? String ?? "."
        let directoryListing = try await FileSystemService.shared.listDirectory(path: path)
        let fileList = directoryListing.files.map { file in
            "\(file.isDirectory ? "📁" : "📄") \(file.name) (\(file.size != nil ? "\(file.size!) bytes" : "unknown size"))"
        }.joined(separator: "\n")
        return "Files in \(directoryListing.path):\n\(fileList)"
    }
}

/// Tool for reading file contents.
class ReadFileTool: Tool {
    let name = "read_file"
    let description = "Read the contents of a file as text. Supports multiple text encodings."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "path": [
                "type": "string",
                "description": "The relative path of the file to read."
            ]
        ],
        "required": ["path"]
    ]
    
    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        guard let path = arguments["path"] as? String else {
            throw ToolError.missingRequiredParameter("path")
        }
        return try await FileSystemService.shared.readFile(path: path)
    }
}

/// Tool for creating new files.
class CreateFileTool: Tool {
    let name = "create_file"
    let description = "Create a new file with the specified content."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "path": [
                "type": "string",
                "description": "The relative path where the new file will be created."
            ],
            "content": [
                "type": "string",
                "description": "The content to write to the new file."
            ]
        ],
        "required": ["path", "content"]
    ]
    
    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        guard let path = arguments["path"] as? String else {
            throw ToolError.missingRequiredParameter("path")
        }
        guard let content = arguments["content"] as? String else {
            throw ToolError.missingRequiredParameter("content")
        }
        try await FileSystemService.shared.createFile(path: path, content: content)
        return "File created successfully at \(path)."
    }
}

/// Tool for writing (overwriting) file contents.
class WriteFileTool: Tool {
    let name = "write_file"
    let description = "Write content to a file, overwriting existing content if the file exists."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "path": [
                "type": "string",
                "description": "The relative path of the file to write to."
            ],
            "content": [
                "type": "string",
                "description": "The content to write to the file."
            ]
        ],
        "required": ["path", "content"]
    ]
    
    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        guard let path = arguments["path"] as? String else {
            throw ToolError.missingRequiredParameter("path")
        }
        guard let content = arguments["content"] as? String else {
            throw ToolError.missingRequiredParameter("content")
        }
        try await FileSystemService.shared.writeFile(path: path, content: content)
        return "Content written to file at \(path)."
    }
}

/// Tool for searching within files.
class SearchFilesTool: Tool {
    let name = "search_files"
    let description = "Search for regular expression patterns across files in the specified directory."
    let parameters: [String: Any] = [
        "type": "object",
        "properties": [
            "path": [
                "type": "string",
                "description": "The relative path of the directory to search in."
            ],
            "regex": [
                "type": "string",
                "description": "The regular expression pattern to search for."
            ],
            "file_pattern": [
                "type": "string",
                "description": "Optional glob pattern to filter files (e.g., '*.txt')."
            ]
        ],
        "required": ["path", "regex"]
    ]
    
    var isEnabled: Bool = true
    var autoApproval: Bool = false

    func execute(arguments: [String: Any]) async throws -> String {
        guard let path = arguments["path"] as? String else {
            throw ToolError.missingRequiredParameter("path")
        }
        guard let regex = arguments["regex"] as? String else {
            throw ToolError.missingRequiredParameter("regex")
        }
        let filePattern = arguments["file_pattern"] as? String

        // Basic implementation - list files and grep-like search
        let listing = try await FileSystemService.shared.listDirectory(path: path)
        var results = [String]()

        for file in listing.files where !file.isDirectory {
            if let filePattern = filePattern {
                let regexPattern = filePattern.replacingOccurrences(of: "*", with: ".*")
                if file.name.range(of: regexPattern, options: .regularExpression) == nil {
                    continue
                }
            }
            do {
                let content = try await FileSystemService.shared.readFile(path: "\(path)/\(file.name)")
                if let _ = content.range(of: regex, options: .regularExpression) {
                    results.append(file.name)
                }
            } catch {
                // Skip files that can't be read
                continue
            }
        }

        return "Files matching '\(regex)' in \(path):\n" + results.joined(separator: "\n")
    }
}
