import Foundation

// MARK: - File System Service

/// Provides file system operations within the working directory
class FileSystemService {
    static let shared = FileSystemService()
    
    private let fileAccessManager: FileAccessManager
    private let fileManager = FileManager.default
    
    init(fileAccessManager: FileAccessManager = .shared) {
        self.fileAccessManager = fileAccessManager
    }
    
    // MARK: - Read Operations
    
    /// List files and directories in the specified path
    func listDirectory(path: String = ".") async throws -> DirectoryListing {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("📂 ディレクトリ一覧取得: \(fullURL.path)")
        
        let contents = try fileManager.contentsOfDirectory(
            at: fullURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey],
            options: [] // 空配列にすることで隠しファイルも表示
        )
        
        let fileInfos = contents.compactMap { url -> FileInfo? in
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey])
                
                return FileInfo(
                    name: url.lastPathComponent,
                    path: url.lastPathComponent,
                    isDirectory: resourceValues.isDirectory ?? false,
                    size: resourceValues.fileSize.map { Int64($0) },
                    modifiedDate: resourceValues.contentModificationDate,
                    createdDate: resourceValues.creationDate
                )
            } catch {
                print("⚠️ ファイル情報取得エラー: \(url.lastPathComponent) - \(error)")
                return nil
            }
        }
        
        print("✅ \(fileInfos.count)個のファイル/ディレクトリを取得")
        return DirectoryListing(path: path, files: fileInfos)
    }
    
    /// Read the contents of a file
    func readFile(path: String) async throws -> String {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("📄 ファイル読み取り: \(fullURL.path)")
        
        guard fileManager.fileExists(atPath: fullURL.path) else {
            throw FileSystemError.fileNotFound
        }
        
        let data = try Data(contentsOf: fullURL)
        print("📊 ファイルサイズ: \(data.count) bytes")
        
        // Try multiple encodings
        let encodings: [String.Encoding] = [.utf8, .utf16, .ascii, .isoLatin1]
        
        for encoding in encodings {
            if let content = String(data: data, encoding: encoding) {
                print("✅ ファイル読み取り成功 (encoding: \(encoding))")
                return content
            }
        }
        
        // If all encodings fail, check if it's a binary file
        if isBinaryFile(data: data) {
            throw FileSystemError.binaryFileNotSupported
        }
        
        throw FileSystemError.encodingError
    }
    
    /// Check if a file exists
    func fileExists(path: String) -> Bool {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            return false
        }
        return fileManager.fileExists(atPath: fullURL.path)
    }
    
    // MARK: - Helper Methods
    
    /// Check if data appears to be binary
    private func isBinaryFile(data: Data) -> Bool {
        // Check first 512 bytes for null bytes or high ratio of non-printable characters
        let sampleSize = min(512, data.count)
        let sample = data.prefix(sampleSize)
        
        var nonPrintableCount = 0
        for byte in sample {
            // Check for null bytes (common in binary files)
            if byte == 0 {
                return true
            }
            // Count non-printable ASCII characters (excluding common whitespace)
            if byte < 32 && byte != 9 && byte != 10 && byte != 13 {
                nonPrintableCount += 1
            }
        }
        
        // If more than 30% non-printable, likely binary
        return Double(nonPrintableCount) / Double(sampleSize) > 0.3
    }
    
    // MARK: - Write Operations
    
    /// Create a new file with content
    func createFile(path: String, content: String) async throws {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("📝 ファイル作成: \(fullURL.path)")
        
        if fileManager.fileExists(atPath: fullURL.path) {
            throw FileSystemError.fileAlreadyExists
        }
        
        guard let data = content.data(using: .utf8) else {
            throw FileSystemError.encodingError
        }
        
        try data.write(to: fullURL, options: .atomic)
        print("✅ ファイル作成成功: \(fullURL.lastPathComponent)")
    }
    
    /// Write content to a file (overwrites existing content)
    func writeFile(path: String, content: String) async throws {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("✍️ ファイル書き込み: \(fullURL.path)")
        
        guard let data = content.data(using: .utf8) else {
            throw FileSystemError.encodingError
        }
        
        try data.write(to: fullURL, options: .atomic)
        print("✅ ファイル書き込み成功: \(fullURL.lastPathComponent)")
    }
    
    /// Append content to a file
    func appendToFile(path: String, content: String) async throws {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("➕ ファイル追記: \(fullURL.path)")
        
        guard let data = content.data(using: .utf8) else {
            throw FileSystemError.encodingError
        }
        
        if fileManager.fileExists(atPath: fullURL.path) {
            let fileHandle = try FileHandle(forWritingTo: fullURL)
            defer { try? fileHandle.close() }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } else {
            try data.write(to: fullURL, options: .atomic)
        }
        
        print("✅ ファイル追記成功: \(fullURL.lastPathComponent)")
    }
    
    // MARK: - Delete Operations
    
    /// Delete a file
    func deleteFile(path: String) async throws {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("🗑️ ファイル削除: \(fullURL.path)")
        
        guard fileManager.fileExists(atPath: fullURL.path) else {
            throw FileSystemError.fileNotFound
        }
        
        try fileManager.removeItem(at: fullURL)
        print("✅ ファイル削除成功: \(fullURL.lastPathComponent)")
    }
    
    /// Delete a directory
    func deleteDirectory(path: String, recursive: Bool = false) async throws {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("🗑️ ディレクトリ削除: \(fullURL.path)")
        
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fullURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw FileSystemError.notADirectory
        }
        
        if !recursive {
            let contents = try fileManager.contentsOfDirectory(atPath: fullURL.path)
            guard contents.isEmpty else {
                throw FileSystemError.directoryNotEmpty
            }
        }
        
        try fileManager.removeItem(at: fullURL)
        print("✅ ディレクトリ削除成功: \(fullURL.lastPathComponent)")
    }
    
    // MARK: - Advanced Operations
    
    /// Create a directory
    func createDirectory(path: String) async throws {
        guard let fullURL = fileAccessManager.validatePath(path) else {
            throw FileSystemError.invalidPath
        }
        
        print("📁 ディレクトリ作成: \(fullURL.path)")
        
        try fileManager.createDirectory(at: fullURL, withIntermediateDirectories: true, attributes: nil)
        print("✅ ディレクトリ作成成功: \(fullURL.lastPathComponent)")
    }
}

// MARK: - Errors

enum FileSystemError: LocalizedError {
    case invalidPath
    case fileNotFound
    case fileAlreadyExists
    case notADirectory
    case directoryNotEmpty
    case encodingError
    case binaryFileNotSupported
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidPath:
            return "Invalid path or path is outside working directory"
        case .fileNotFound:
            return "File not found"
        case .fileAlreadyExists:
            return "File already exists"
        case .notADirectory:
            return "Path is not a directory"
        case .directoryNotEmpty:
            return "Directory is not empty"
        case .encodingError:
            return "Failed to encode/decode file content (unsupported text encoding)"
        case .binaryFileNotSupported:
            return "Binary files are not supported. Only text files can be read."
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
