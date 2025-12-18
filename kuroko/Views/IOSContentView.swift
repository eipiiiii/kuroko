import SwiftUI

// MARK: - iOS Content View

struct IOSContentView: View {
    @Bindable var viewModel: KurokoViewModel
    @State private var isShowingSettings = false
    @State private var isShowingHistory = false

    var body: some View {
        NavigationStack {
            ChatView(viewModel: viewModel)
                .navigationTitle("kuroko")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { isShowingHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button(action: {
                                viewModel.startNewSession()
                            }) {
                                Image(systemName: "square.and.pencil")
                            }

                            Button(action: { isShowingSettings = true }) {
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(sessionManager: viewModel.sessionManager)
                        .onDisappear {
                            viewModel.updateModelConfiguration()
                        }
                }
                .sheet(isPresented: $isShowingHistory) {
                    SessionHistoryView(sessionManager: viewModel.sessionManager)
                        .onDisappear {
                            viewModel.loadCurrentSession()
                        }
                }
        }
    }
}
