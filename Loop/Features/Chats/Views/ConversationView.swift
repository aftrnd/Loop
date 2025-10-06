import SwiftUI

struct ConversationView: View {
    let chat: Chat
    @State private var viewModel: ConversationViewModel

    init(chat: Chat) {
        self.chat = chat
        _viewModel = State(wrappedValue: ConversationViewModel(chatId: chat.id.uuidString))
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty && !viewModel.isLoading {
                            // Empty state
                            VStack(spacing: 20) {
                                Image(systemName: "message.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue.opacity(0.6))

                                Text("Start the conversation")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Text("Send a message to begin chatting with \(chat.displayTitle)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                            }
                            .padding(.top, 100)
                        } else if viewModel.isLoading {
                            // Loading state
                            VStack(spacing: 20) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading messages...")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 100)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    // bottom inset reserved by safeAreaInset
                }
                .onChange(of: viewModel.messages.count) {
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .interactiveKeyboardDismiss()
            }
            }
            .navigationTitle(chat.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, alignment: .center, spacing: 0) {
                MessageInputView(messageText: $viewModel.messageText) {
                    viewModel.sendMessage()
                }
                .zIndex(1)
                .background(Color.clear)
            }
    }
}

#Preview {
    NavigationStack {
        ConversationView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message"))
    }
}
