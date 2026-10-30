import SwiftUI

/// One heart in a burst. Its motion is a closed-form function of elapsed time, so nothing is stored per frame.
struct HeartParticle {
    let initialOffset: CGSize
    let velocity: CGSize
    let initialScale: CGFloat
    let initialRotation: Double
    let angularVelocity: Double

    static let gravity: CGFloat = 250 // Points per second squared
    static let duration: Double = 0.9
    static let fadeStart: Double = 0.3 // Fraction of the duration before fading begins

    /// Shrink curve: each 60 fps step multiplies the scale by `1 - 0.3 * progress`.
    private static let shrinkSteps: [CGFloat] = {
        let frames = Int(duration * 60)
        var steps: [CGFloat] = [1]
        for frame in 1...frames {
            let progress = CGFloat(frame) / CGFloat(frames)
            steps.append(steps[frame - 1] * (1 - progress * 0.3))
        }
        return steps
    }()

    func offset(at time: Double) -> CGSize {
        let t = CGFloat(time)
        return CGSize(
            width: initialOffset.width + velocity.width * t,
            height: initialOffset.height + velocity.height * t + 0.5 * Self.gravity * t * t
        )
    }

    func rotation(at time: Double) -> Double {
        initialRotation + angularVelocity * time
    }

    func opacity(at time: Double) -> Double {
        let fadeStartTime = Self.fadeStart * Self.duration
        guard time > fadeStartTime else { return 1 }
        return max(0, 1 - (time - fadeStartTime) / (Self.duration - fadeStartTime))
    }

    func scale(at time: Double) -> CGFloat {
        let position = min(max(time * 60, 0), Double(Self.shrinkSteps.count - 1))
        let lower = Int(position)
        let upper = min(lower + 1, Self.shrinkSteps.count - 1)
        let fraction = CGFloat(position - Double(lower))
        let shrink = Self.shrinkSteps[lower] + (Self.shrinkSteps[upper] - Self.shrinkSteps[lower]) * fraction
        return initialScale * shrink
    }

    /// Ten hearts spread evenly around the circle, each with a little random variation.
    static func burst() -> [HeartParticle] {
        let particleCount = 10
        return (0..<particleCount).map { index in
            let radians = (2 * .pi / Double(particleCount)) * Double(index)
            let speed = CGFloat.random(in: 80...120)
            // Start a few points from center, shifted down 2pt to sit on the heart icon
            let initialOffset = CGSize(width: .random(in: -4...4), height: .random(in: -4...4) + 2)
            return HeartParticle(
                initialOffset: initialOffset,
                velocity: CGSize(width: cos(radians) * speed, height: sin(radians) * speed),
                initialScale: .random(in: 0.6...1.0),
                initialRotation: .random(in: -180...180),
                angularVelocity: .random(in: -360...360)
            )
        }
    }
}

struct HeartParticleAnimationView: View {
    var iconSize: CGFloat = 18
    var triggerID: UUID

    private struct Burst: Identifiable {
        let id = UUID()
        let startDate: Date
        let particles: [HeartParticle]
    }

    @State private var bursts: [Burst] = []

    private let heartSymbolID = 0

    var body: some View {
        ZStack {
            // Only mounted while a burst is playing, so idle rows carry no timeline
            if !bursts.isEmpty {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        guard let heart = context.resolveSymbol(id: heartSymbolID) else { return }
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)

                        for burst in bursts {
                            let time = min(timeline.date.timeIntervalSince(burst.startDate), HeartParticle.duration)
                            guard time >= 0 else { continue }

                            for particle in burst.particles {
                                let offset = particle.offset(at: time)
                                let scale = particle.scale(at: time)
                                var heartContext = context
                                heartContext.opacity = particle.opacity(at: time)
                                heartContext.translateBy(x: center.x + offset.width, y: center.y + offset.height)
                                heartContext.rotate(by: .degrees(particle.rotation(at: time)))
                                heartContext.scaleBy(x: scale, y: scale)
                                heartContext.draw(heart, at: .zero)
                            }
                        }
                    } symbols: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: iconSize * 0.5))
                            .foregroundColor(.red)
                            .tag(heartSymbolID)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: triggerID) {
            startBurst()
        }
    }

    private func startBurst() {
        let burst = Burst(startDate: .now, particles: HeartParticle.burst())
        bursts.append(burst)

        Task {
            try? await Task.sleep(for: .seconds(1))
            bursts.removeAll { $0.id == burst.id }
        }
    }
}

// Preview
#Preview {
    @Previewable @State var triggerID = UUID()

    VStack(spacing: 40) {
        HeartParticleAnimationView(triggerID: triggerID)
            .frame(width: 200, height: 200)

        Button("Burst") {
            triggerID = UUID()
        }
    }
    .padding()
}
