import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - File Access Manager

/// Manages security-scoped access to user-selected directories
@Observable
class FileAccessManager {
    static let shared = FileAccessManager()
    
    var workingDirectoryURL: URL?
    
    private let userDefaults = UserDefaults.standard
    private let workingDirectoryKey = "fileSystemWorkingDirectory"
    
    init() {
        loadWorkingDirectory()
    }
    
    // MARK: - Directory Management
    
    func setWorkingDirectory(_ url: URL) {
        // 以前のURLへのアクセスを停止
        if let oldURL = workingDirectoryURL {
            oldURL.stopAccessingSecurityScopedResource()
        }
        
        // セキュリティスコープリソースへのアクセス開始
        if url.startAccessingSecurityScopedResource() {
            workingDirectoryURL = url
        } else {
            workingDirectoryURL = url
        }
        
        // セキュリティスコープ付きブックマークを保存
        do {
            #if os(macOS)
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            userDefaults.set(bookmarkData, forKey: workingDirectoryKey)
        } catch {
            // ブックマーク保存エラーは無視
        }
    }
    
    private func loadWorkingDirectory() {
        guard let bookmarkData = userDefaults.data(forKey: workingDirectoryKey) else {
            return
        }

        do {
            var isStale = false
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                let newBookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                userDefaults.set(newBookmarkData, forKey: workingDirectoryKey)
            }
            #else
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)

            if isStale {
                let newBookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                userDefaults.set(newBookmarkData, forKey: workingDirectoryKey)
            }
            #endif

            if url.startAccessingSecurityScopedResource() {
                workingDirectoryURL = url
            }
        } catch {
            // ブックマーク読み込みエラーは無視
        }
    }
    
    func clearWorkingDirectory() {
        if let url = workingDirectoryURL {
            url.stopAccessingSecurityScopedResource()
        }
        workingDirectoryURL = nil
        userDefaults.removeObject(forKey: workingDirectoryKey)
    }
    
    func getCurrentWorkingDirectoryPath() -> String? {
        return workingDirectoryURL?.path
    }
    
    // MARK: - Path Validation
    
    func validatePath(_ relativePath: String) -> URL? {
        guard let workingDir = workingDirectoryURL else {
            return nil
        }

        // 相対パスから絶対パスを構築
        let fullURL = workingDir.appendingPathComponent(relativePath)

        // パスが作業ディレクトリ内にあることを確認
        guard fullURL.path.hasPrefix(workingDir.path) else {
            return nil
        }

        return fullURL
    }
}
