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
    
    init(id: UUID = UUID(), title: String = "新しい会話", messages: [SessionMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
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
        saveDirectoryURL = url
        
        // セキュリティスコープ付きブックマークを保存
        do {
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            userDefaults.set(bookmarkData, forKey: saveDirectoryKey)
        } catch {
            print("ブックマーク保存エラー: \(error)")
        }
        
        // セッションを再読み込み
        loadSessions()
    }
    
    private func loadSaveDirectory() {
        guard let bookmarkData = userDefaults.data(forKey: saveDirectoryKey) else {
            return
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // ブックマークが古い場合は再作成
                let newBookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                userDefaults.set(newBookmarkData, forKey: saveDirectoryKey)
            }
            
            // セキュリティスコープリソースにアクセス
            if url.startAccessingSecurityScopedResource() {
                saveDirectoryURL = url
            }
        } catch {
            print("ブックマーク読み込みエラー: \(error)")
        }
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
            
            let mdFiles = fileURLs.filter { $0.pathExtension == "md" }
            
            var loadedSessions: [ChatSession] = []
            for fileURL in mdFiles {
                if let session = loadSessionFromMarkdown(url: fileURL) {
                    loadedSessions.append(session)
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
            sessionToSave.title = String(firstUserMessage.prefix(30))
        }
        
        sessionToSave.updatedAt = Date()
        
        let fileName = "\(sessionToSave.id.uuidString).md"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        
        let markdownContent = generateMarkdown(from: sessionToSave)
        
        do {
            try markdownContent.write(to: fileURL, atomically: true, encoding: .utf8)
            currentSession = sessionToSave
            
            // セッションリストを更新
            if let index = sessions.firstIndex(where: { $0.id == sessionToSave.id }) {
                sessions[index] = sessionToSave
            } else {
                sessions.insert(sessionToSave, at: 0)
            }
        } catch {
            print("セッション保存エラー: \(error)")
        }
    }
    
    func loadSession(_ session: ChatSession) {
        currentSession = session
    }
    
    func deleteSession(_ session: ChatSession) {
        guard let directoryURL = saveDirectoryURL else { return }
        
        let fileName = "\(session.id.uuidString).md"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            sessions.removeAll { $0.id == session.id }
            
            if currentSession?.id == session.id {
                currentSession = nil
            }
        } catch {
            print("セッション削除エラー: \(error)")
        }
    }
    
    // MARK: - Markdown Conversion
    
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
                  let createdAt = ISO8601DateFormatter().date(from: createdString),
                  let updatedAt = ISO8601DateFormatter().date(from: updatedString) else {
                return nil
            }
            
            // メッセージをパース
            let bodyContent = lines[contentStartIndex...].joined(separator: "\n")
            let messages = parseMessages(from: bodyContent)
            
            return ChatSession(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
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
