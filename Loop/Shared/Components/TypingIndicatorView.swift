import SwiftUI

struct TypingIndicatorView: View {
    @State private var startTime = Date()
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016)) { timeline in
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(dotScale(for: index, at: timeline.date))
                        .opacity(dotOpacity(for: index, at: timeline.date))
                }
            }
        }
        .frame(height: 20)
        .onAppear {
            startTime = Date()
        }
    }
    
    private func dotScale(for index: Int, at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSince(startTime)
        // Animates left to right: first dot (index 0) starts, then 1, then 2
        let phase = (elapsed - Double(index) * 0.2).truncatingRemainder(dividingBy: 1.2)
        let normalized = phase / 1.2
        
        // Ease in-out using sine wave
        let sine = sin(normalized * .pi)
        return 0.7 + (sine * 0.6) // Ranges from 0.7 to 1.3
    }
    
    private func dotOpacity(for index: Int, at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(startTime)
        // Animates left to right: first dot (index 0) starts, then 1, then 2
        let phase = (elapsed - Double(index) * 0.2).truncatingRemainder(dividingBy: 1.2)
        let normalized = phase / 1.2
        
        // Ease in-out using sine wave
        let sine = sin(normalized * .pi)
        return 0.4 + (sine * 0.6) // Ranges from 0.4 to 1.0
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

