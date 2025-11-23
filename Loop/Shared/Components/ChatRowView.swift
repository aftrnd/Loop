import SwiftUI

struct ChatRowView: View {
    let chat: Chat
    var parallax: CGFloat = 0
    var onAvatarTap: (() -> Void)?
    
    // Layout constants
    private let rowLeadingPadding: CGFloat = 10
    private let listRowLeadingInset: CGFloat = 10 // From listRowInsets in ChatsListView
    private let dotSize: CGFloat = 8
    
    // Debug overlay
    @AppStorage("showLayoutDebugOverlays") private var showDebugOverlay = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Unread indicator dot - positioned to the left of avatar
            if chat.unreadCount > 0 {
                let totalLeadingSpace = listRowLeadingInset + rowLeadingPadding
                let dotOffset = totalLeadingSpace / 2 - dotSize / 2
                let verticalOffset = CardLayoutConstants.topPadding + (CardLayoutConstants.avatarSize / 2) - (dotSize / 2)
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: dotOffset, y: verticalOffset)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                // Use PostHeader component with message preview in username slot
                PostHeader(
                    avatarURL: chat.otherParticipantAvatarURL,
                    displayName: chat.displayTitle,
                    username: chat.lastMessagePreview, // Message preview goes in username position
                    badgeType: chat.isGroupChat ? nil : chat.otherParticipantBadgeType,
                    timestamp: formatTime(chat.lastMessageTime),
                    trailingIcon: "chevron.right",
                    showUsernamePrefix: false, // Don't show "@" for message preview
                    onAvatarTap: !chat.isGroupChat ? onAvatarTap : nil,
                    showDebugOverlay: showDebugOverlay
                )
                .padding(.trailing, 10)
            }
        }
        .offset(y: 0)
        .padding(.leading, rowLeadingPadding)
        .padding(.trailing, 0) // No trailing padding to allow time to extend to edge
        .padding(.top, CardLayoutConstants.topPadding)
        .padding(.bottom, CardLayoutConstants.bottomPadding)
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
