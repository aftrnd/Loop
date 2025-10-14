import SwiftUI
import UIKit

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    var onTextChanged: (() -> Void)? = nil
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...6)
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
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Color.clear
                .glassEffect(.regular, in: Capsule())
        )
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