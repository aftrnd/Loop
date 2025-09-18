import SwiftUI
import UIKit

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $messageText)
                .textFieldStyle(.plain)
                .font(.body)
                .submitLabel(.send)
                .onSubmit(onSend)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .lineLimit(1)
                .focused($isFocused)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Color.clear
                        .glassEffect(.regular, in: Capsule())
                        .allowsHitTesting(false)
                )
            
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(messageText.isEmpty ? Color.secondary : Color.white)
                    .overlay(
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .mask(
                                Image(systemName: "arrow.up.circle.fill").font(.title2)
                            )
                            .opacity(messageText.isEmpty ? 0 : 1)
                    )
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    @Previewable @State var messageText = ""
    struct Host: View {
        @State var text: String = ""
        var body: some View {
            VStack {
                Spacer()
                MessageInputView(messageText: $text) {}
            }
            .background(Color(.systemBackground))
        }
    }
    return Host()
}
