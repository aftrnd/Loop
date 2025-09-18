import SwiftUI

struct ChatRowView: View {
    let chat: Chat
    var parallax: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                
                Color.clear
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular, in: Circle())
                
                Text(String(chat.title.prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .overlay(alignment: .topTrailing) {
                if chat.unreadCount > 0 {
                    Circle()
                        .fill(colorScheme == .light ? Color.red : Color.blue)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Text(badgeText(chat.unreadCount))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        .offset(x: 7, y: -7)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chat.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(formatTime(chat.lastMessageTime))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 16)
                }
                
                HStack {
                    Text(chat.lastMessagePreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Spacer()
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .offset(y: 0)
        .padding(.leading, 16)
        .padding(.trailing, 0) // No trailing padding to allow time to extend to edge
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .compositingGroup()
        // Parallax is now applied at the row container level in ChatsListView
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .short
        }
        
        return formatter.string(from: date)
    }

    private func badgeText(_ count: Int) -> String {
        if count > 99 { return "99+" }
        return "\(count)"
    }
}

#Preview {
    List {
        ChatRowView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message preview"))
    }
}
