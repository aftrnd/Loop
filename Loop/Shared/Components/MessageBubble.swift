import SwiftUI

struct MessageBubble: View {
    let message: Message
    @State private var showTimestamp = false
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
                
                // Timestamp on left for sent messages
                if showTimestamp {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                if let senderName = message.senderName, !message.isFromUser {
                    Text(senderName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                }
                
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.isFromUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.isFromUser {
                                Color.blue
                            } else {
                                Color(.systemGray5)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    )
                    .scaleEffect(isPressed ? 0.95 : 1.0)
            }
            
            if !message.isFromUser {
                // Timestamp on right for received messages
                if showTimestamp {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 20)
        .contentShape(Rectangle())
        .onTapGesture {
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