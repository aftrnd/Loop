import SwiftUI

struct NotesView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Notes")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Create and organize your notes")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .navigationTitle("Notes")
        }
    }
}

#Preview {
    NotesView()
}
