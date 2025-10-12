import SwiftUI
import UIKit

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    var onTextChanged: (() -> Void)? = nil
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $messageText)
                .textFieldStyle(.plain)
                .font(.body)
                .submitLabel(.send)
                .onSubmit(onSend)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .focused($isFocused)
                .onChange(of: messageText) { _, _ in
                    onTextChanged?()
                }
            
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(messageText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.clear
                .glassEffect(.regular, in: Capsule())
        )
        .padding(.horizontal, 20)
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