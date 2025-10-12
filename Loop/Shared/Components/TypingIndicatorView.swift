import SwiftUI

struct TypingIndicatorView: View {
    @State private var animationPhase = [false, false, false]
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase[index] ? 1.2 : 0.8)
                    .opacity(animationPhase[index] ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true),
                        value: animationPhase[index]
                    )
            }
        }
        .frame(height: 20) // Match typical message text height
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startAnimation() {
        // Stagger the animation for each dot
        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                animationPhase[index] = true
            }
        }
    }
}

#Preview {
    VStack {
        TypingIndicatorView()
            .padding()
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    .padding()
}

