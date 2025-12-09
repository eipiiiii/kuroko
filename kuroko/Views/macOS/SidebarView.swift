import SwiftUI

struct SidebarView: View {
    @Bindable var sessionManager: SessionManager
    @Bindable var viewModel: KurokoViewModel
    @State private var searchText = ""
    @State private var showingSettings = false
    
    var filteredSessions: [ChatSession] {
        if searchText.isEmpty {
            return sessionManager.sessions
        } else {
            return sessionManager.sessions.filter { session in
                session.title.localizedCaseInsensitiveContains(searchText) ||
                session.messages.contains { $0.text.localizedCaseInsensitiveContains(searchText) }
            }
        }
    }
    
    var body: some View {
        List {
            if sessionManager.sessions.isEmpty {
                ContentUnavailableView {
                    Label("No History", systemImage: "clock")
                } description: {
                    Text("Start a new chat to see it here.")
                }
            } else {
                ForEach(filteredSessions) { session in
                    SessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sessionManager.loadSession(session)
                            viewModel.loadCurrentSession()
                        }
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            sessionManager.currentSession?.id == session.id ?
                            Color.accentColor.opacity(0.2) : Color.clear
                        )
                        .cornerRadius(8)
                }
                .onDelete(perform: deleteSessions)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search History")
        .safeAreaInset(edge: .bottom) {
             HStack {
                Group {
                    #if os(macOS)
                    SettingsLink {
                        Label("Settings", systemImage: "gear")
                    }
                    #else
                    Button(action: {
                        showingSettings = true
                    }) {
                        Label("Settings", systemImage: "gear")
                    }
                    #endif
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding()
                 Spacer()
             }
             .background(.ultraThinMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.startNewSession()
                }) {
                    Label("New Chat", systemImage: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(sessionManager: sessionManager)
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = filteredSessions[index]
            sessionManager.deleteSession(session)
        }
    }
}
