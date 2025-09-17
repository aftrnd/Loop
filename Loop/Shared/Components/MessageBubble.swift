import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
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
                        ZStack {
                            if message.isFromUser {
                                LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                            } else {
                                Color.clear
                                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                            }
                        }
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }
            
            if !message.isFromUser {
                Spacer(minLength: 50)
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
