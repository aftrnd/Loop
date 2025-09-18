import SwiftUI

struct ConversationView: View {
    let chat: Chat
    @State private var messageText = ""
    @State private var messages: [Message] = []
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.purple.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            // Empty state
                            VStack(spacing: 20) {
                                Image(systemName: "message.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue.opacity(0.6))
                                
                                Text("Start the conversation")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Text("Send a message to begin chatting with \(chat.title)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    // bottom inset reserved by safeAreaInset
                }
                .onChange(of: messages.count) {
                    if let lastMessage = messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .interactiveKeyboardDismiss()
            }
            }
            .navigationTitle(chat.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadMessages()
            }
            .safeAreaInset(edge: .bottom, alignment: .center, spacing: 0) {
                MessageInputView(messageText: $messageText) {
                    sendMessage()
                }
                .zIndex(1)
                .background(Color.clear)
            }
    }
    
    private func loadMessages() {
        // Load sample messages for demonstration
        messages = [
            Message(content: "Hey! How are you doing?", isFromUser: false, senderName: chat.title),
            Message(content: "I'm doing great! Thanks for asking. How about you?", isFromUser: true),
            Message(content: "Pretty good! Just working on some new features for the app.", isFromUser: false, senderName: chat.title),
            Message(content: "That sounds exciting! What kind of features are you working on?", isFromUser: true),
            Message(content: "We're adding some really cool UI improvements with liquid glass effects and better message bubbles.", isFromUser: false, senderName: chat.title)
        ]
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = Message(content: messageText, isFromUser: true)
        messages.append(newMessage)
        messageText = ""
        
        // Simulate response after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let responses = [
                "That's interesting!",
                "I see what you mean.",
                "Thanks for sharing that with me.",
                "That sounds great!",
                "I'm glad to hear that."
            ]
            let response = responses.randomElement() ?? "Thanks!"
            let responseMessage = Message(content: response, isFromUser: false, senderName: chat.title)
            messages.append(responseMessage)
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message"))
    }
}
