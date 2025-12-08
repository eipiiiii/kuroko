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
    @State private var showingFolderPicker = false
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
                Color(red: 0.05, green: 0.05, blue: 0.05).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // フォルダ設定セクション
                    if sessionManager.saveDirectoryURL == nil {
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 60))
                                .foregroundStyle(.cyan)
                            
                            Text("保存先フォルダを選択してください")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("会話履歴をMarkdownファイルとして\n選択したフォルダに保存します")
                                .font(.caption)
                                .foregroundStyle(.gray)
                                .multilineTextAlignment(.center)
                            
                            Button(action: { showingFolderPicker = true }) {
                                Label("フォルダを選択", systemImage: "folder")
                                    .font(.body)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.cyan)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // セッションリスト
                        List {
                            Section {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(.cyan)
                                    Text(sessionManager.saveDirectoryURL?.lastPathComponent ?? "未選択")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button("変更") {
                                        showingFolderPicker = true
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                                }
                                .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                            }
                            
                            Section(header: Text("会話履歴").foregroundStyle(.white)) {
                                if filteredSessions.isEmpty {
                                    ContentUnavailableView {
                                        Image(systemName: "text.bubble")
                                            .font(.system(size: 40))
                                            .foregroundStyle(.gray)
                                    } description: {
                                        Text(searchText.isEmpty ? "保存された会話がありません" : "検索結果がありません")
                                            .foregroundStyle(.gray)
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
                                            .listRowBackground(Color(red: 0.15, green: 0.15, blue: 0.15))
                                    }
                                    .onDelete(perform: deleteSessions)
                                }
                            }
                        }
                        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "会話を検索")
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("会話履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
                
                if sessionManager.saveDirectoryURL != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            sessionManager.loadSessions()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                handleFolderSelection(result)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = filteredSessions[index]
            sessionManager.deleteSession(session)
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                sessionManager.setSaveDirectory(url)
            }
        case .failure(let error):
            print("フォルダ選択エラー: \(error)")
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
                .foregroundStyle(.white)
            
            Text(preview)
                .font(.caption)
                .foregroundStyle(.gray)
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
            .foregroundStyle(.gray)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionHistoryView(sessionManager: SessionManager())
}
