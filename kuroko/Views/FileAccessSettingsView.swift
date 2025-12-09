import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Access Settings View

struct FileAccessSettingsView: View {
    @Bindable var fileAccessManager: FileAccessManager
    @State private var showingFolderPicker = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "folder")
                    Text("Working Directory")
                    Spacer()
                    Text(fileAccessManager.workingDirectoryURL?.lastPathComponent ?? "Not Selected")
                        .foregroundStyle(.secondary)
                }
                
                Button("Select Folder...") {
                    showingFolderPicker = true
                }
                
                if fileAccessManager.workingDirectoryURL != nil {
                    Button("Clear Access", role: .destructive) {
                        fileAccessManager.clearWorkingDirectory()
                    }
                }
            } header: {
                Text("File System Access")
            } footer: {
                Text("Select a folder to allow the AI to read and write files. The AI will only have access to files within this folder.")
                    .font(.caption)
            }
            
            if let path = fileAccessManager.getCurrentWorkingDirectoryPath() {
                Section {
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } header: {
                    Text("Full Path")
                }
            }
        }
        .navigationTitle("File Access")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                fileAccessManager.setWorkingDirectory(url)
            }
        case .failure(let error):
            print("❌ Folder selection error: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        FileAccessSettingsView(fileAccessManager: FileAccessManager.shared)
    }
}
