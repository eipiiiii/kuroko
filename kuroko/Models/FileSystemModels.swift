import Foundation

// MARK: - File System Models

/// Information about a file or directory
struct FileInfo: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedDate: Date?
    let createdDate: Date?
    
    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        isDirectory: Bool,
        size: Int64? = nil,
        modifiedDate: Date? = nil,
        createdDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
        self.createdDate = createdDate
    }
}

/// Result of listing a directory
struct DirectoryListing: Codable {
    let path: String
    let files: [FileInfo]
    let totalCount: Int
    
    init(path: String, files: [FileInfo]) {
        self.path = path
        self.files = files
        self.totalCount = files.count
    }
}

/// Types of file operations
enum FileOperationType: String, Codable {
    case read
    case write
    case delete
    case create
    case list
    case move
    case copy
}

/// Result of a file operation
struct FileOperationResult: Codable {
    let success: Bool
    let message: String
    let data: String?
    
    init(success: Bool, message: String, data: String? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}
