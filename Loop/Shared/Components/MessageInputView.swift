import SwiftUI
import UIKit

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    var onTextChanged: (() -> Void)? = nil
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 8) {
            // Text field matching iOS 26 search field style
            TextField("Message", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...6)
                .submitLabel(.send)
                .onSubmit(onSend)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .focused(isFocused)
                .onChange(of: messageText) { _, _ in
                    onTextChanged?()
                }
            
            // Send button inside the text field
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(messageText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
            }
            .disabled(messageText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 38)
        .background(
            Color.clear
                .glassEffect(.regular, in: Capsule())
        )
        .padding(.horizontal, isFocused.wrappedValue ? 0 : 20)
        .animation(.easeInOut(duration: 0.25), value: isFocused.wrappedValue)
    }
}

#Preview {
    struct Host: View {
        @State var text: String = ""
        @FocusState var focused: Bool
        var body: some View {
            VStack {
                Spacer()
                MessageInputView(messageText: $text, onSend: {}, isFocused: $focused)
            }
            .background(Color(.systemBackground))
        }
    }
    return Host()
}