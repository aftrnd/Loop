import SwiftUI

struct MessageBubble: View {
    let message: Message
    @State private var showTimestamp = false
    @State private var isPressed = false
    @State private var hasAppeared = false
    
    var body: some View {
        Group {
            if message.isFromUser {
                sentMessageView
            } else {
                receivedMessageView
            }
        }
        .scaleEffect(hasAppeared ? 1.0 : 0.5)
        .opacity(hasAppeared ? 1.0 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .blur(radius: hasAppeared ? 0 : 3)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55, blendDuration: 0)) {
                hasAppeared = true
            }
        }
    }
    
    private var receivedMessageView: some View {
        HStack(alignment: .center, spacing: 0) {
            // Message bubble
            Text(message.content)
                .font(.body)
                .foregroundColor(.primary)
                .padding(.horizontal, AppConstants.UI.padding)
                .padding(.vertical, AppConstants.UI.spacing + 2)
                .background(
                    Color(.systemGray5)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.66, alignment: .leading)
            
            // Timestamp
            if showTimestamp {
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, AppConstants.UI.spacing)
            }
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleTimestamp)
    }
    
    private var sentMessageView: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            
            if showTimestamp {
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.trailing, AppConstants.UI.spacing)
            }
            
            Text(message.content)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, AppConstants.UI.padding)
                .padding(.vertical, AppConstants.UI.spacing + 2)
                .background(
                    Color.blue
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.66, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleTimestamp)
    }
    
    private func toggleTimestamp() {
        // Subtle bounce animation for tap feedback
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
            isPressed = true
        }
        
        // Quick release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
                isPressed = false
            }
        }
        
        // Smooth timestamp reveal with spring
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0)) {
            showTimestamp.toggle()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubble(message: Message(content: "Hey! How are you doing?", isFromUser: false, senderName: "Alex"))
        MessageBubble(message: Message(content: "I'm doing great! Thanks for asking. How about you?", isFromUser: true))
        MessageBubble(message: Message(content: "Pretty good! Just working on some new features for the app.", isFromUser: false, senderName: "Alex"))
    }
    .padding()
    .background(Color(.systemBackground))
}