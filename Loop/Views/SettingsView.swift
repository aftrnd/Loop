import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @State private var showDebugSettings = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // Developer Section
            Section {
                Button {
                    showDebugSettings = true
                } label: {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                            .frame(width: 30)
                        
                        Text("Developer Settings")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Developer")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Color.clear
                            .glassEffect(.regular, in: Capsule())
                    )
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showDebugSettings) {
            DebugMenuView()
        }
    }
}

#Preview {
    SettingsView()
}
