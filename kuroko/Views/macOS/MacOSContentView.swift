import SwiftUI

// MARK: - macOS Content View

struct MacOSContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var viewModel: KurokoViewModel
    
    var body: some View {
        NavigationSplitView {
            SidebarView(sessionManager: viewModel.sessionManager, viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            ChatView(viewModel: viewModel)
                .background(themeManager.backgroundColor)
        }
        .navigationTitle(viewModel.sessionManager.currentSession?.title ?? "kuroko")
    }
}
