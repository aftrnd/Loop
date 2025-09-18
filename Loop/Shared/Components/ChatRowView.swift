import SwiftUI

struct ChatRowView: View {
    let chat: Chat
    var parallax: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
                .overlay(alignment: .center) {
                    Text(String(chat.title.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .overlay(alignment: .topTrailing) {
                    if chat.unreadCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                            Text(badgeText(chat.unreadCount))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        .frame(width: 22, height: 22)
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
                    
                    HStack(spacing: 6) {
                        Text(formatTime(chat.lastMessageTime))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
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
        .padding(.horizontal, 16)
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
