import Foundation
import SwiftUI

// MARK: - View State
enum ViewState: Equatable {
    case idle
    case loading
    case error(String)
    
    static func == (lhs: ViewState, rhs: ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Kuroko ViewModel

/// Lean UI state coordinator for the chat interface.
/// Delegates business logic to specialized, abstract services.
@Observable
public class KurokoViewModel {
    // MARK: - UI State
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var viewState: ViewState = .idle
    
    // MARK: - Services (Injected through protocols)
    private let configService: KurokoConfigurationService
    private var llmService: LLMService
    private let toolExecutor: ToolExecutor
    let sessionManager: SessionManager
    
    // MARK: - Task Management
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Initialization
    public init(
        configService: KurokoConfigurationService = .shared,
        toolExecutor: ToolExecutor = DefaultToolExecutor(),
        sessionManager: SessionManager = .shared
    ) {
        self.configService = configService
        self.toolExecutor = toolExecutor
        self.sessionManager = sessionManager
        
        // The initial LLM service is created by the factory.
        // This can fail if the default selected model is somehow unsupported.
        do {
            self.llmService = try LLMServiceFactory.createService(for: configService.selectedModel.provider)
        } catch {
            self.llmService = UnsupportedLLMService()
            self.viewState = .error(error.localizedDescription)
        }
        
        loadCurrentSession()
    }
    
    // MARK: - Public Methods
    
    /// Called when model configuration changes in settings.
    func updateModelConfiguration() {
        configService.loadConfiguration()
        do {
            self.llmService = try LLMServiceFactory.createService(for: configService.selectedModel.provider)
        } catch {
            self.llmService = UnsupportedLLMService()
            self.viewState = .error(error.localizedDescription)
        }
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        currentTask = nil
        if case .loading = viewState {
            viewState = .idle
        }
        
        // Mark last message as stopped
        if let lastIndex = messages.indices.last, messages[lastIndex].isStreaming {
            messages[lastIndex].isStreaming = false
            if !messages[lastIndex].text.isEmpty {
                messages[lastIndex].text += "\n\n⚠️ 生成を停止しました"
            }
        }
    }
    
    func retryLastMessage() {
        // Simple retry logic can be enhanced later
    }
    
    @MainActor
    func sendMessage() {
        let userMessageText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessageText.isEmpty else { return }
        
        // Reset state
        inputText = ""
        viewState = .loading
        
        // Append user message
        messages.append(ChatMessage(role: .user, text: userMessageText))
        
        // Append placeholder for AI response
        let aiMessageIndex = messages.count
        messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
        
        currentTask = Task {
            do {
                try await processMessage(text: userMessageText, aiMessageIndex: aiMessageIndex)
            } catch {
                await MainActor.run {
                    if let toolError = error as? ToolError {
                        self.viewState = .error("Tool Error: \(toolError.localizedDescription)")
                    } else {
                        self.viewState = .error("Error: \(error.localizedDescription)")
                    }
                    messages[aiMessageIndex].isStreaming = false
                }
            }
        }
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        messages = []
        sessionManager.createNewSession()
    }
    
    func loadCurrentSession() {
        if let session = sessionManager.currentSession {
            messages = session.messages.map { ChatMessage(from: $0) }
        }
    }
    
    func saveCurrentSession() {
        let sessionMessages = messages.map { SessionMessage(from: $0) }
        if sessionManager.currentSession != nil {
            sessionManager.currentSession?.messages = sessionMessages
            sessionManager.currentSession?.updatedAt = Date()
        } else {
            sessionManager.currentSession = ChatSession(messages: sessionMessages)
        }
        sessionManager.saveCurrentSession()
    }
    
    // MARK: - Private Core Logic
    
    private func processMessage(text: String, aiMessageIndex: Int) async throws {
        let history = messages.dropLast() // Exclude the placeholder
        let config = LLMConfig(model: configService.selectedModel)
        
        try await llmService.sendMessage(
            message: text,
            history: Array(history),
            config: config,
            onChunk: { [weak self] chunk in
                Task { @MainActor in
                    self?.messages[aiMessageIndex].text += chunk
                }
            },
            onToolCall: { [weak self] toolCall in
                Task { @MainActor in
                    self?.handleToolCall(toolCall, aiMessageIndex: aiMessageIndex)
                }
            }
        )
        
        await MainActor.run {
            messages[aiMessageIndex].isStreaming = false
            viewState = .idle
            saveCurrentSession()
        }
    }
    
    @MainActor
    private func handleToolCall(_ toolCall: ToolCall, aiMessageIndex: Int) {
        // Update message with tool call info
        messages[aiMessageIndex].toolCalls = [toolCall]
        messages[aiMessageIndex].isStreaming = false
        
        // Add visual indicator for the tool call
        messages[aiMessageIndex].text += "\n\n\(toolCall.function.name)..." // Simple indicator
        
        // Execute the tool and process the result
        Task {
            do {
                let result = try await toolExecutor.executeToolCall(toolCall)
                
                await MainActor.run {
                    // Add tool result message
                    messages.append(ChatMessage(role: .tool, text: result, toolCallId: toolCall.id))
                    
                    // Add a new placeholder for the AI's final response
                    let newAiIndex = messages.count
                    messages.append(ChatMessage(role: .model, text: "", isStreaming: true))
                    
                    // Make a new call to the LLM with the tool result
                    Task {
                        try await self.processMessage(text: "", aiMessageIndex: newAiIndex)
                    }
                }
            } catch {
                viewState = .error("Tool Error: \(error.localizedDescription)")
            }
        }
    }
}
