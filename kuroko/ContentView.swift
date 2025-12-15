import SwiftUI

// MARK: - Content View (Platform Router)

/// Main content view for iOS
struct ContentView: View {
    @State private var viewModel = KurokoViewModel()

    var body: some View {
        IOSContentView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
