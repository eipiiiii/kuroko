import Foundation
import SwiftUI

// MARK: - View State
enum ViewState: Equatable {
    case idle
    case loading
    case awaitingApproval
    case error(String)

    static func == (lhs: ViewState, rhs: ViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.awaitingApproval, .awaitingApproval): return true
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
    var operationMode: OperationMode = .act
    
    // MARK: - Services (Injected through protocols)
    private let configService: KurokoConfigurationService
    private var llmService: LLMService
    private let toolExecutor: ToolExecutor
    let sessionManager: SessionManager
    private var agentRunner: AgentRunner?
    
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
        guard !messages.isEmpty else { return }

        // Find the last user message
        guard let lastUserMessageIndex = messages.lastIndex(where: { $0.role == .user }) else { return }
        let lastUserMessage = messages[lastUserMessageIndex]

        // Remove all messages after the last user message (assistant responses, tool calls, etc.)
        messages.removeSubrange((lastUserMessageIndex + 1)..<messages.endIndex)

        // Reset agent runner
        agentRunner = nil

        // Reset state
        inputText = lastUserMessage.text
        viewState = .idle

        // Send the message again
        sendMessage()
    }

    func approveToolCall() async {
        Task {
            do {
                try await agentRunner?.approveToolCall()
            } catch {
                viewState = .error("Error approving tool call: \(error.localizedDescription)")
            }
        }
    }

    func rejectToolCall() async {
        Task {
            do {
                try await agentRunner?.rejectToolCall()
            } catch {
                viewState = .error("Error rejecting tool call: \(error.localizedDescription)")
            }
        }
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

        // Log user message
        print("[CHAT] User: \(userMessageText)")

        // Initialize agent runner if needed
        if agentRunner == nil {
            agentRunner = AgentRunner(
                config: configService.createAgentConfig(),
                llmService: llmService,
                toolExecutor: toolExecutor,
                systemPrompt: configService.getCombinedPrompt()
            )
            agentRunner?.onMessageAdded = { [weak self] message in
                Task { @MainActor in
                    guard let self = self else { return }
                    // If the last message is from the assistant, update it. Otherwise, append a new one.
                    // This handles the streaming case where the message is progressively built.
                    if self.messages.last?.role == .assistant {
                        self.messages[self.messages.count - 1] = message
                    } else {
                        self.messages.append(message)

                        // Log assistant messages
                        if message.role == .assistant && !message.isStreaming {
                            print("[CHAT] Assistant: \(message.text)")
                        } else if message.role == .toolResult {
                            print("[CHAT] Tool Result: \(message.text)")
                        }
                    }
                }
            }
            agentRunner?.onStateChange = { [weak self] state in
                Task { @MainActor in
                    self?.handleAgentStateChange(state)
                }
            }
        }

        currentTask = Task {
            do {
                // Start agent with full conversation history
                try await self.agentRunner?.startWithHistory(self.messages)
            } catch {
                await MainActor.run {
                    if let toolError = error as? ToolError {
                        self.viewState = .error("Tool Error: \(toolError.localizedDescription)")
                        print("[ERROR] Tool Error: \(toolError.localizedDescription)")
                    } else {
                        self.viewState = .error("Error: \(error.localizedDescription)")
                        print("[ERROR] Agent Error: \(error.localizedDescription)")
                    }

                    // If an error occurs, ensure the streaming state is stopped.
                    if let lastIndex = self.messages.indices.last, self.messages[lastIndex].isStreaming {
                        self.messages[lastIndex].isStreaming = false
                    }
                }
            }
        }
    }
    
    // MARK: - Session Management

    func startNewSession() {
        messages = []
        agentRunner = nil
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

    @MainActor
    private func handleAgentStateChange(_ state: AgentState) {
        switch state {
        case .awaitingApproval:
            viewState = .awaitingApproval
        case .executingTool:
            // Keep loading state during tool execution
            viewState = .loading
        case .completed:
            viewState = .idle
            saveCurrentSession()
        case .failed(let error):
            viewState = .error("Agent Error: \(error)")
        default:
            break
        }
    }
}
