import Foundation
import SwiftUI

// MARK: - Kuroko ViewModel

/// Lean UI state coordinator for the chat interface
/// Delegates business logic to specialized services
@Observable
class KurokoViewModel {
    // MARK: - UI State
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Task Management
    private var currentTask: Task<Void, Never>?
    private var lastUserMessage: String?
    
    // MARK: - Services (Dependency Injection)
    private let configService: APIConfigurationService
    private let geminiService: GeminiServiceProtocol
    private let openRouterService: OpenRouterServiceProtocol
    let sessionManager: SessionManager
    
    // MARK: - Initialization
    
    init(
        configService: APIConfigurationService = .shared,
        geminiService: GeminiServiceProtocol = GeminiService(),
        openRouterService: OpenRouterServiceProtocol = OpenRouterService(),
        sessionManager: SessionManager = .shared
    ) {
        self.configService = configService
        self.geminiService = geminiService
        self.openRouterService = openRouterService
        self.sessionManager = sessionManager
        
        loadCurrentSession()
    }
    
    // MARK: - Public Methods
    
    func updateModelConfiguration() {
        configService.loadConfiguration()
        
        // Update Gemini service if it's the selected provider
        if configService.selectedProvider == "gemini",
           let gemini = geminiService as? GeminiService {
            gemini.updateModelConfiguration()
        }
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        
        // Mark last message as stopped
        if let lastIndex = messages.indices.last,
           messages[lastIndex].isStreaming {
            messages[lastIndex].isStreaming = false
            if !messages[lastIndex].text.isEmpty {
                messages[lastIndex].text += "\n\n⚠️ 生成を停止しました"
            }
        }
    }
    
    func retryLastMessage() {
        guard let lastMessage = lastUserMessage else { return }
        
        // Remove last AI response if present and it's an error or empty
        if let lastIndex = messages.indices.last,
           messages[lastIndex].role == .model {
            messages.removeLast()
        }
        
        errorMessage = nil
        inputText = lastMessage
        sendMessage()
    }
    
    
    @MainActor
    func sendMessage() {
        updateModelConfiguration()
        
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Check API key
        guard configService.hasValidApiKey() else {
            errorMessage = configService.getApiKeyErrorMessage()
            return
        }
        
        let userMessage = inputText
        inputText = ""
        errorMessage = nil
        
        messages.append(ChatMessage(role: .user, text: userMessage))
        isLoading = true
        
        // Store for retry functionality
        lastUserMessage = userMessage
        
        let aiMessageIndex = messages.count
        messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
        
        currentTask = Task {
            do {
                if configService.selectedProvider == "gemini" {
                    try await sendGeminiMessage(userMessage: userMessage, aiMessageIndex: aiMessageIndex)
                } else {
                    try await sendOpenRouterMessage(userMessage: userMessage, aiMessageIndex: aiMessageIndex)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    messages[aiMessageIndex].isStreaming = false
                    errorMessage = "エラー: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func startNewSession() {
        messages = []
        sessionManager.createNewSession()
    }
    
    func loadCurrentSession() {
        if let session = sessionManager.currentSession {
            messages = session.messages.map { sessionMessage in
                ChatMessage(
                    role: sessionMessage.role == "user" ? .user : (sessionMessage.role == "tool" ? .tool : .model),
                    text: sessionMessage.text,
                    isStreaming: false
                )
            }
        }
    }
    
    func saveCurrentSession() {
        let sessionMessages = messages.map { message in
            SessionMessage(
                role: message.role.rawValue,
                text: message.text
            )
        }
        
        if sessionManager.currentSession != nil {
            sessionManager.currentSession?.messages = sessionMessages
            sessionManager.currentSession?.updatedAt = Date()
        } else {
            sessionManager.currentSession = ChatSession(messages: sessionMessages)
        }
        
        sessionManager.saveCurrentSession()
    }
    
    // MARK: - Private Methods
    
    private func sendGeminiMessage(userMessage: String, aiMessageIndex: Int) async throws {
        let history = messages.dropLast()
        
        try await geminiService.sendMessage(userMessage, history: Array(history)) { [weak self] chunk in
            Task { @MainActor in
                self?.messages[aiMessageIndex].text += chunk
            }
        }
        
        await MainActor.run {
            messages[aiMessageIndex].isStreaming = false
            isLoading = false
            saveCurrentSession()
        }
    }
    
    private func sendOpenRouterMessage(userMessage: String, aiMessageIndex: Int) async throws {
        let history = messages.dropLast()
        
        try await openRouterService.sendMessage(
            userMessage,
            history: Array(history),
            onChunk: { [weak self] chunk in
                Task { @MainActor in
                    self?.messages[aiMessageIndex].text += chunk
                }
            },
            onToolCall: { [weak self] toolCall in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    
                    // Update message with tool call
                    self.messages[aiMessageIndex].toolCalls = [toolCall]
                    self.messages[aiMessageIndex].isStreaming = false
                    
                    // Add visual indicator
                    if toolCall.function.name == "google_search",
                       let argsData = toolCall.function.arguments.data(using: .utf8),
                       let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any],
                       let query = argsDict["query"] as? String {
                        self.messages[aiMessageIndex].text += "\n\n🔍 **Searching:** \(query)"
                    }
                    
                    // Execute tool
                    do {
                        if let openRouter = self.openRouterService as? OpenRouterService {
                            let result = try await openRouter.executeToolCall(toolCall)
                            
                            await MainActor.run {
                                // Add tool result
                                self.messages.append(ChatMessage(role: .tool, text: result, toolCallId: toolCall.id))
                                // Add new AI placeholder
                                self.messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
                            }
                            
                            // Recursive call for final answer
                            let newAiIndex = await MainActor.run { self.messages.count - 1 }
                            try await self.sendOpenRouterMessage(userMessage: "", aiMessageIndex: newAiIndex)
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = "Tool execution error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        )
        
        await MainActor.run {
            messages[aiMessageIndex].isStreaming = false
            isLoading = false
            saveCurrentSession()
        }
    }
}
