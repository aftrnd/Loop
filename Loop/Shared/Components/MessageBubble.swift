import SwiftUI
import UIKit
import FirebaseAuth

struct MessageBubble: View {
    let message: Message
    let isGroupChat: Bool
    var onLike: (() -> Void)?
    @State private var showTimestamp = false
    @State private var isPressed = false
    @State private var hasAppeared = false
    @State private var showHeartAnimation = false
    @State private var heartOffset: CGFloat = 0
    @State private var heartRotation: Double = 0
    @State private var heartScale: CGFloat = 0.5
    @State private var heartOpacity: Double = 1.0
    
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
            withAnimation(.spring()) {
                hasAppeared = true
            }
            
        }
    }
    
    private var receivedMessageView: some View {
        HStack(alignment: .center, spacing: 0) {
            // Message bubble with like overlay
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
                .overlay(alignment: .topTrailing) {
                    // Like indicator
                    if message.likeCount > 0, let currentUserId = getCurrentUserId() {
                        let isLikedByCurrentUser = message.isLikedBy(userId: currentUserId)
                        let bubbleHeight: CGFloat = 34
                        
                        ZStack(alignment: .center) {
                            // Glass bubble background (drawn from center)
                            if isGroupChat {
                                Capsule()
                                    .fill(Color.clear)
                                    .glassEffect(isLikedByCurrentUser ? .regular : .clear, in: Capsule())
                                    .frame(height: bubbleHeight)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .glassEffect(isLikedByCurrentUser ? .regular : .clear, in: Circle())
                                    .frame(width: bubbleHeight, height: bubbleHeight)
                            }
                            
                            // Content on top - perfectly centered
                            if isGroupChat {
                                HStack(spacing: 4) {
                                    Text("❤️")
                                        .font(.system(size: 14))
                                    Text("\(message.likeCount)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 8)
                            } else {
                                Text("❤️")
                                    .font(.system(size: 14))
                            }
                        }
                        .offset(
                            x: isGroupChat ? (bubbleHeight + 16) * 0.65 - 5 : bubbleHeight * 0.65 - 5,
                            y: -bubbleHeight * 0.65 + 5
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .center) {
                    // Heart animation overlay - floating and levitating
                    if showHeartAnimation {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                            .scaleEffect(heartScale)
                            .offset(y: heartOffset)
                            .rotationEffect(.degrees(heartRotation))
                            .opacity(heartOpacity)
                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
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
        .onTapGesture(count: 2, perform: handleDoubleTap)
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
            
            // Message bubble with like overlay
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
                .overlay(alignment: .topLeading) {
                    // Like indicator
                    if message.likeCount > 0, let currentUserId = getCurrentUserId() {
                        let isLikedByCurrentUser = message.isLikedBy(userId: currentUserId)
                        let bubbleHeight: CGFloat = 34
                        
                        ZStack(alignment: .center) {
                            // Glass bubble background (drawn from center)
                            if isGroupChat {
                                Capsule()
                                    .fill(Color.clear)
                                    .glassEffect(isLikedByCurrentUser ? .regular : .clear, in: Capsule())
                                    .frame(height: bubbleHeight)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .glassEffect(isLikedByCurrentUser ? .regular : .clear, in: Circle())
                                    .frame(width: bubbleHeight, height: bubbleHeight)
                            }
                            
                            // Content on top - perfectly centered
                            if isGroupChat {
                                HStack(spacing: 4) {
                                    Text("❤️")
                                        .font(.system(size: 14))
                                    Text("\(message.likeCount)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                .padding(.horizontal, 8)
                            } else {
                                Text("❤️")
                                    .font(.system(size: 14))
                            }
                        }
                        .offset(
                            x: isGroupChat ? -(bubbleHeight + 16) * 0.65 + 5 : -bubbleHeight * 0.65 + 5,
                            y: -bubbleHeight * 0.65 + 5
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .center) {
                    // Heart animation overlay - floating and levitating
                    if showHeartAnimation {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                            .scaleEffect(heartScale)
                            .offset(y: heartOffset)
                            .rotationEffect(.degrees(heartRotation))
                            .opacity(heartOpacity)
                            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.66, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleTimestamp)
        .onTapGesture(count: 2, perform: handleDoubleTap)
    }
    
    private func toggleTimestamp() {
        // Subtle bounce animation for tap feedback
        withAnimation(.spring()) {
            isPressed = true
        }
        
        // Quick release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring()) {
                isPressed = false
            }
        }
        
        // Smooth timestamp reveal with spring
        withAnimation(.spring()) {
            showTimestamp.toggle()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func handleDoubleTap() {
        // Reset state
        showHeartAnimation = true
        heartOffset = 0
        heartScale = 0.5
        heartRotation = 0
        heartOpacity = 1.0
        
        // Bounce and float up with native spring animation
        withAnimation(.spring()) {
            heartScale = 1.2
            heartOffset = -60
            heartRotation = Double.random(in: -5...5)
        }
        
        // Fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut) {
                heartOpacity = 0
            }
        }
        
        // Hide after fade completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showHeartAnimation = false
        }
        
        // Call the like callback with haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        onLike?()
    }
    
    private func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubble(message: Message(content: "Hey! How are you doing?", isFromUser: false, senderName: "Alex"), isGroupChat: false)
        MessageBubble(message: Message(content: "I'm doing great! Thanks for asking. How about you?", isFromUser: true), isGroupChat: false)
        MessageBubble(message: Message(content: "Pretty good! Just working on some new features for the app.", isFromUser: false, senderName: "Alex"), isGroupChat: false)
    }
    .padding()
    .background(Color(.systemBackground))
}
