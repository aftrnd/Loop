import SwiftUI
import UIKit

struct MessageInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    var onTextChanged: (() -> Void)? = nil
    @FocusState private var isFocused: Bool
    
    // Padding values
    private let defaultPadding: CGFloat = 18  // Distance from edge when not focused
    private let focusedPadding: CGFloat = 5   // Distance from edge when focused
    
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
        .padding(.horizontal, AppConstants.UI.padding)
        .padding(.vertical, AppConstants.UI.spacing + 2)
        .background(
            Color.clear
                .glassEffect(.regular, in: Capsule())
        )
        .padding(.horizontal, isFocused ? -(defaultPadding - focusedPadding) : 0)
        .padding(.vertical, 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isFocused)
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