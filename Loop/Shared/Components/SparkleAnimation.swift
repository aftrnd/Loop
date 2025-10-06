import SwiftUI

struct SparkleAnimation: View {
    @State private var sparkles: [SparkleParticle] = []
    
    let sparkleCount = 12
    let animationDuration: Double = 1.5
    
    var body: some View {
        ZStack {
            ForEach(sparkles) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: sparkle.size))
                    .foregroundColor(sparkle.color)
                    .offset(x: sparkle.offsetX, y: sparkle.offsetY)
                    .opacity(sparkle.opacity)
                    .scaleEffect(sparkle.scale)
                    .rotationEffect(.degrees(sparkle.rotation))
            }
        }
        .onAppear {
            createSparkles()
            // Auto-trigger animation when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animateSparkles()
            }
        }
    }
    
    private func createSparkles() {
        sparkles = (0..<sparkleCount).map { _ in
            SparkleParticle(
                id: UUID(),
                size: Double.random(in: 8...16),
                color: [.blue, .cyan, .purple, .pink, .yellow].randomElement() ?? .blue,
                offsetX: 0,
                offsetY: 0,
                opacity: 0,
                scale: 0,
                rotation: Double.random(in: 0...360)
            )
        }
    }
    
    private func animateSparkles() {
        // Reset sparkles to center
        for i in sparkles.indices {
            sparkles[i].offsetX = 0
            sparkles[i].offsetY = 0
            sparkles[i].opacity = 0
            sparkles[i].scale = 0
        }
        
        // Animate sparkles outward
        withAnimation(.easeOut(duration: animationDuration)) {
            for i in sparkles.indices {
                let angle = Double(i) * (360.0 / Double(sparkleCount)) * .pi / 180
                let distance = Double.random(in: 40...80)
                
                sparkles[i].offsetX = cos(angle) * distance
                sparkles[i].offsetY = sin(angle) * distance
                sparkles[i].opacity = 1.0
                sparkles[i].scale = 1.0
                sparkles[i].rotation += 180
            }
        }
        
        // Fade out sparkles
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.6) {
            withAnimation(.easeIn(duration: animationDuration * 0.4)) {
                for i in sparkles.indices {
                    sparkles[i].opacity = 0
                    sparkles[i].scale = 0.5
                }
            }
        }
    }
}

struct SparkleParticle: Identifiable {
    let id: UUID
    let size: Double
    let color: Color
    var offsetX: Double
    var offsetY: Double
    var opacity: Double
    var scale: Double
    var rotation: Double
}

#Preview {
    VStack {
        Button("Trigger Sparkles") {
            // Preview trigger
        }
        .overlay {
            SparkleAnimation()
        }
    }
    .frame(width: 200, height: 200)
}
