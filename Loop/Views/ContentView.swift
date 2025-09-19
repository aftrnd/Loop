import SwiftUI

struct ContentView: View {
    var body: some View {
        ChatsListView()
            .debugMenu() // Add debug menu support
    }
}

#Preview {
    ContentView()
}
