//
//  SessionHistoryView.swift
//  kuroko
//
//  Created by AI Assistant on 2025/12/08.
//

import SwiftUI
import UniformTypeIdentifiers

struct SessionHistoryView: View {
    @Bindable var sessionManager: SessionManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
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
        NavigationStack {
            ZStack {
                #if os(iOS)
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                #endif
                
                VStack(spacing: 0) {
                    // フォルダ設定セクション
                    if sessionManager.saveDirectoryURL == nil {
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 60))
                                .foregroundStyle(.cyan)
                            
                            Text("保存先が未設定です")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("設定画面から会話履歴を保存する\nフォルダを選択してください")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // セッションリスト
                        List {
                            Section(header: Text("会話履歴").foregroundStyle(.secondary)) {
                                if filteredSessions.isEmpty {
                                    ContentUnavailableView {
                                        Image(systemName: "text.bubble")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.secondary)
                                    } description: {
                                        Text(searchText.isEmpty ? "保存された会話がありません" : "検索結果がありません")
                                            .foregroundStyle(.secondary)
                                    }
                                    .listRowBackground(Color.clear)
                                } else {
                                    ForEach(filteredSessions) { session in
                                        SessionRow(session: session)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                sessionManager.loadSession(session)
                                                dismiss()
                                            }
                                        // Use default list row background
                                    }
                                    .onDelete(perform: deleteSessions)
                                }
                            }
                        }

                        .searchable(text: $searchText, placement: .automatic, prompt: "会話を検索")
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("会話履歴")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            // .toolbarColorScheme(.dark, for: .navigationBar) // Removed
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    // .foregroundStyle(.white) // Use default tint
                }
                
                if sessionManager.saveDirectoryURL != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            sessionManager.loadSessions()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                            // .foregroundStyle(.white) // Use default tint
                        }
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                if sessionManager.saveDirectoryURL != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sessionManager.loadSessions()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
                #endif
            }
            .onAppear {
                if sessionManager.saveDirectoryURL != nil {
                    sessionManager.loadSessions()
                }
            }
            // .preferredColorScheme(.dark) // Removed
        }
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = filteredSessions[index]
            sessionManager.deleteSession(session)
        }
    }
}

struct SessionRow: View {
    let session: ChatSession
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter
    }
    
    private var preview: String {
        session.messages.first { $0.role == "user" }?.text.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines) ?? "空の会話"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(preview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                Image(systemName: "message")
                    .font(.caption2)
                Text("\(session.messages.count) メッセージ")
                    .font(.caption2)
                Spacer()
                Text(dateFormatter.string(from: session.updatedAt))
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionHistoryView(sessionManager: SessionManager())
}