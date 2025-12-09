//
//  SessionManager.swift
//  kuroko
//
//  Created by AI Assistant on 2025/12/08.
//

import Foundation
import SwiftUI

// MARK: - Session Model
struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [SessionMessage]
    
    init(id: UUID = UUID(), title: String = "新しい会話", createdAt: Date = Date(), updatedAt: Date = Date(), messages: [SessionMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
}

struct SessionMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: String // "user" or "model"
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Session Manager
@Observable
class SessionManager {
    static let shared = SessionManager()
    
    var sessions: [ChatSession] = []
    var currentSession: ChatSession?
    var saveDirectoryURL: URL?
    
    private let userDefaults = UserDefaults.standard
    private let saveDirectoryKey = "sessionSaveDirectory"
    
    init() {
        loadSaveDirectory()
        loadSessions()
    }
    
    // MARK: - Directory Management
    
    func setSaveDirectory(_ url: URL) {
        // 以前のURLへのアクセスを停止 (もしあれば)
        if let oldURL = saveDirectoryURL {
            oldURL.stopAccessingSecurityScopedResource()
        }
        
        // セキュリティスコープリソースへのアクセス開始
        if url.startAccessingSecurityScopedResource() {
            saveDirectoryURL = url
            print("保存ディレクトリを設定: \(url.path)")
        } else {
            print("セキュリティスコープリソースへのアクセス失敗 (setSaveDirectory)")
            // 失敗してもとりあえず設定 (非サンドボックス環境などのため)
            saveDirectoryURL = url
        }
        
        // セキュリティスコープ付きブックマークを保存
        do {
            #if os(macOS)
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            #endif
            userDefaults.set(bookmarkData, forKey: saveDirectoryKey)
        } catch {
            print("ブックマーク保存エラー: \(error)")
        }
        
        // セッションを再読み込み
        loadSessions()
    }
    
    private func loadSaveDirectory() {
        guard let bookmarkData = userDefaults.data(forKey: saveDirectoryKey) else {
            // デフォルトでアプリのDocumentsディレクトリを使用
            setupDefaultDirectory()
            return
        }
        
        do {
            var isStale = false
            #if os(macOS)
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // ブックマークが古い場合は再作成
                let newBookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                userDefaults.set(newBookmarkData, forKey: saveDirectoryKey)
            }
            #else
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // ブックマークが古い場合は再作成
                let newBookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                userDefaults.set(newBookmarkData, forKey: saveDirectoryKey)
            }
            #endif
            
            // セキュリティスコープリソースにアクセス
            if url.startAccessingSecurityScopedResource() {
                saveDirectoryURL = url
                print("保存ディレクトリを設定: \(url.path)")
            } else {
                print("セキュリティスコープリソースへのアクセス失敗")
                setupDefaultDirectory()
            }
        } catch {
            print("ブックマーク読み込みエラー: \(error)")
            setupDefaultDirectory()
        }
    }
    
    private func setupDefaultDirectory() {
        // アプリのDocumentsディレクトリを使用
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let kurokoURL = documentsURL.appendingPathComponent("Kuroko")
        
        do {
            if !FileManager.default.fileExists(atPath: kurokoURL.path) {
                try FileManager.default.createDirectory(at: kurokoURL, withIntermediateDirectories: true, attributes: nil)
            }
            saveDirectoryURL = kurokoURL
            print("デフォルトディレクトリを使用: \(kurokoURL.path)")
        } catch {
            print("デフォルトディレクトリ作成失敗: \(error)")
        }
    }
    
    func getCurrentSaveDirectoryPath() -> String? {
        return saveDirectoryURL?.path
    }
    
    // MARK: - Session Management
    
    func createNewSession() {
        let newSession = ChatSession()
        currentSession = newSession
    }
    
    func loadSessions() {
        guard let directoryURL = saveDirectoryURL else {
            sessions = []
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            // JSONファイルとMDファイルを収集
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            
            var loadedSessions: [ChatSession] = []
            var loadedIds: Set<UUID> = []
            
            // JSONから読み込み（優先）
            for fileURL in jsonFiles {
                if let session = loadSessionFromJSON(url: fileURL) {
                    loadedSessions.append(session)
                    loadedIds.insert(session.id)
                }
            }
            
            // MDから読み込み（JSONがない場合のみ）
            for fileURL in mdFiles {
                // ファイル名からIDを取得して重複チェック
                let fileName = fileURL.deletingPathExtension().lastPathComponent
                if let id = UUID(uuidString: fileName), !loadedIds.contains(id) {
                     if let session = loadSessionFromMarkdown(url: fileURL) {
                        loadedSessions.append(session)
                    }
                }
            }
            
            sessions = loadedSessions.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            print("セッション読み込みエラー: \(error)")
            sessions = []
        }
    }
    
    func saveCurrentSession() {
        guard let session = currentSession,
              let directoryURL = saveDirectoryURL else {
            return
        }
        
        // タイトルが「新しい会話」の場合、最初のメッセージから生成
        var sessionToSave = session
        if sessionToSave.title == "新しい会話" && !sessionToSave.messages.isEmpty {
            let firstUserMessage = sessionToSave.messages.first { $0.role == "user" }?.text ?? "会話"
            sessionToSave.title = firstUserMessage.replacingOccurrences(of: "\n", with: " ").prefix(30).trimmingCharacters(in: .whitespaces)
        }
        
        sessionToSave.updatedAt = Date()
        
        // JSONで保存
        let fileName = "\(sessionToSave.id.uuidString).json"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        
        // 古いMDファイルのパス（存在すれば削除するため）
        let legacyFileName = "\(sessionToSave.id.uuidString).md"
        let legacyFileURL = directoryURL.appendingPathComponent(legacyFileName)
        
        // 保存処理をバックグラウンドで実行
        Task.detached(priority: .background) {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(sessionToSave)
                try data.write(to: fileURL, options: .atomic)
                
                // 保存に成功したら、古いMDファイルを削除（移行完了）
                if FileManager.default.fileExists(atPath: legacyFileURL.path) {
                    try FileManager.default.removeItem(at: legacyFileURL)
                    print("Legacy markdown file migrated and deleted: \(legacyFileName)")
                }
            } catch {
                print("セッション保存エラー: \(error)")
            }
        }
        
        // メモリ内のデータを更新
        currentSession = sessionToSave
        
        // セッションリストを更新
        if let index = sessions.firstIndex(where: { $0.id == sessionToSave.id }) {
            sessions[index] = sessionToSave
        } else {
            sessions.insert(sessionToSave, at: 0)
        }
    }
    
    func loadSession(_ session: ChatSession) {
        currentSession = session
    }
    
    func deleteSession(_ session: ChatSession) {
        guard let directoryURL = saveDirectoryURL else { return }
        
        let jsonFileName = "\(session.id.uuidString).json"
        let jsonFileURL = directoryURL.appendingPathComponent(jsonFileName)
        
        let mdFileName = "\(session.id.uuidString).md"
        let mdFileURL = directoryURL.appendingPathComponent(mdFileName)
        
        do {
            // 両方の可能性を試す
            if FileManager.default.fileExists(atPath: jsonFileURL.path) {
                try FileManager.default.removeItem(at: jsonFileURL)
            }
            if FileManager.default.fileExists(atPath: mdFileURL.path) {
                try FileManager.default.removeItem(at: mdFileURL)
            }
            
            sessions.removeAll { $0.id == session.id }
            
            if currentSession?.id == session.id {
                currentSession = nil
            }
        } catch {
            print("セッション削除エラー: \(error)")
        }
    }
    
    // MARK: - JSON Loading
    
    private func loadSessionFromJSON(url: URL) -> ChatSession? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ChatSession.self, from: data)
        } catch {
            print("JSON読み込みエラー (\(url.lastPathComponent)): \(error)")
            return nil
        }
    }

    // MARK: - Markdown Conversion (Legacy Support)
    
    private func generateMarkdown(from session: ChatSession) -> String {
        var markdown = """
        ---
        id: \(session.id.uuidString)
        title: \(session.title)
        created: \(ISO8601DateFormatter().string(from: session.createdAt))
        updated: \(ISO8601DateFormatter().string(from: session.updatedAt))
        ---
        
        # \(session.title)
        
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for message in session.messages {
            let role = message.role == "user" ? "👤 User" : "🤖 Assistant"
            let timestamp = dateFormatter.string(from: message.timestamp)
            
            markdown += """
            
            ## \(role)
            *\(timestamp)*
            
            \(message.text)
            
            ---
            
            """
        }
        
        return markdown
    }
    
    private func loadSessionFromMarkdown(url: URL) -> ChatSession? {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // フロントマターをパース
            let lines = content.components(separatedBy: .newlines)
            var metadata: [String: String] = [:]
            var inFrontMatter = false
            var contentStartIndex = 0
            
            for (index, line) in lines.enumerated() {
                if line == "---" {
                    if !inFrontMatter {
                        inFrontMatter = true
                    } else {
                        contentStartIndex = index + 1
                        break
                    }
                } else if inFrontMatter {
                    let parts = line.split(separator: ":", maxSplits: 1)
                    if parts.count == 2 {
                        let key = parts[0].trimmingCharacters(in: .whitespaces)
                        let value = parts[1].trimmingCharacters(in: .whitespaces)
                        metadata[key] = value
                    }
                }
            }
            
            // メタデータからセッション情報を取得
            guard let idString = metadata["id"],
                  let id = UUID(uuidString: idString),
                  let title = metadata["title"],
                  let createdString = metadata["created"],
                  let updatedString = metadata["updated"],
                  let created = ISO8601DateFormatter().date(from: createdString),
                  let updated = ISO8601DateFormatter().date(from: updatedString) else {
                return nil
            }
            
            // メッセージをパース
            let bodyContent = lines[contentStartIndex...].joined(separator: "\n")
            let messages = parseMessages(from: bodyContent)
            
            return ChatSession(
                id: id,
                title: title,
                createdAt: created,
                updatedAt: updated,
                messages: messages
            )
        } catch {
            print("マークダウン読み込みエラー: \(error)")
            return nil
        }
    }
    
    private func parseMessages(from content: String) -> [SessionMessage] {
        var messages: [SessionMessage] = []
        let sections = content.components(separatedBy: "---")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            let lines = trimmed.components(separatedBy: .newlines)
            var role: String?
            var timestamp: Date?
            var messageText = ""
            var inMessage = false
            
            for line in lines {
                if line.hasPrefix("## 👤 User") {
                    role = "user"
                } else if line.hasPrefix("## 🤖 Assistant") {
                    role = "model"
                } else if line.hasPrefix("*") && line.hasSuffix("*") {
                    let timeString = line.trimmingCharacters(in: CharacterSet(charactersIn: "*"))
                    timestamp = dateFormatter.date(from: timeString)
                    inMessage = true
                } else if inMessage && !line.isEmpty {
                    messageText += line + "\n"
                }
            }
            
            if let role = role {
                messages.append(SessionMessage(
                    role: role,
                    text: messageText.trimmingCharacters(in: .whitespacesAndNewlines),
                    timestamp: timestamp ?? Date()
                ))
            }
        }
        
        return messages
    }
}
