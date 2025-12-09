import SwiftUI

// MARK: - Content View (Platform Router)

/// Main content view that routes to platform-specific implementations
struct ContentView: View {
    @State private var viewModel = KurokoViewModel()
    
    var body: some View {
        #if os(macOS)
        MacOSContentView(viewModel: viewModel)
        #else
        IOSContentView(viewModel: viewModel)
        #endif
    }
}

#Preview {
    ContentView()
}
