import SwiftUI

struct ChatRowView: View {
    let chat: Chat
    var parallax: CGFloat = 0
    var onAvatarTap: (() -> Void)?
    
    // Layout constants
    private let rowLeadingPadding: CGFloat = 10
    private let listRowLeadingInset: CGFloat = 10 // From listRowInsets in ChatsListView
    private let dotSize: CGFloat = 8
    
    var body: some View {
        HStack(spacing: CardLayoutConstants.avatarSpacing) { // 20pt - consistent with posts
            // Avatar with unread dot
            ZStack(alignment: .leading) {
                // Unread indicator dot - positioned to the left of avatar
                if chat.unreadCount > 0 {
                    let totalLeadingSpace = listRowLeadingInset + rowLeadingPadding
                    let dotOffset = -(totalLeadingSpace / 2 + dotSize / 2)
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: dotSize, height: dotSize)
                        .offset(x: dotOffset) // Centered between screen edge and avatar
                }
                
                // Avatar
                ZStack {
                    if let avatarURLString = chat.otherParticipantAvatarURL, let avatarURL = URL(string: avatarURLString) {
                        // Show actual user avatar
                        CachedAsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: CardLayoutConstants.avatarSize, height: CardLayoutConstants.avatarSize)
                                .clipShape(Circle())
                        } placeholder: {
                            // Placeholder while loading
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: CardLayoutConstants.avatarSize, height: CardLayoutConstants.avatarSize)
                                .overlay {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                        }
                    } else {
                        // Default avatar with initials
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: CardLayoutConstants.avatarSize, height: CardLayoutConstants.avatarSize)
                        
                        Color.clear
                            .frame(width: CardLayoutConstants.avatarSize, height: CardLayoutConstants.avatarSize)
                            .glassEffect(.regular, in: Circle())
                        
                        Text(String(chat.displayTitle.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .onTapGesture {
                    // Only show profile for 1:1 chats
                    if !chat.isGroupChat {
                        onAvatarTap?()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Text(chat.displayTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        // Badge if user has one (only for 1:1 chats)
                        if !chat.isGroupChat, let badgeType = chat.otherParticipantBadgeType {
                            Image(systemName: badgeType.iconName)
                                .font(.system(size: 14))
                                .foregroundColor(badgeType.color)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(formatTime(chat.lastMessageTime))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Image(systemName: "chevron.right")
                            .font(.subheadline) // Match the time font size
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 10)
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
        .padding(.leading, rowLeadingPadding)
        .padding(.trailing, 0) // No trailing padding to allow time to extend to edge
        .padding(.top, 8)
        .padding(.bottom, 12)
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
}

#Preview {
    List {
        ChatRowView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message preview"))
    }
}
