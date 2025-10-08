import SwiftUI

struct HeartParticle: Identifiable {
    let id = UUID()
    var offset: CGSize
    var velocity: CGSize
    var scale: CGFloat
    var opacity: Double
    var rotation: Double
    var angularVelocity: Double
}

struct HeartParticleAnimationView: View {
    @State private var particles: [HeartParticle] = []
    @State private var isAnimating = false
    
    let isLiked: Bool
    var iconSize: CGFloat = 18
    var trigger: Bool = false
    
    var body: some View {
        ZStack {
            // Only render particles (main heart is rendered in LoopCardView)
            ForEach(particles) { particle in
                Image(systemName: "heart.fill")
                    .font(.system(size: iconSize * 0.5))
                    .foregroundColor(.red)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .rotationEffect(.degrees(particle.rotation))
                    .offset(particle.offset)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: trigger) { _, _ in
            triggerAnimation()
        }
    }
    
    private func triggerAnimation() {
        // Prevent overlapping animations
        guard !isAnimating else { return }
        isAnimating = true
        
        // Generate particles with initial velocities
        let particleCount = 10
        var newParticles: [HeartParticle] = []
        
        for i in 0..<particleCount {
            let angle = (360.0 / Double(particleCount)) * Double(i)
            let radians = angle * .pi / 180
            
            // Initial velocity (explosion outward)
            let speed: CGFloat = CGFloat.random(in: 80...120)
            let velocityX = cos(radians) * speed
            let velocityY = sin(radians) * speed
            
            let particle = HeartParticle(
                offset: .zero,
                velocity: CGSize(width: velocityX, height: velocityY),
                scale: CGFloat.random(in: 0.6...1.0),
                opacity: 1.0,
                rotation: Double.random(in: -180...180),
                angularVelocity: Double.random(in: -360...360)
            )
            newParticles.append(particle)
        }
        
        particles = newParticles
        
        // Physics-based animation with gravity
        animateParticlesWithGravity()
        
        // Clear particles and reset animation lock
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            particles.removeAll()
            isAnimating = false
        }
    }
    
    private func animateParticlesWithGravity() {
        let gravity: CGFloat = 250 // Pixels per second squared
        let duration: Double = 0.9
        let fps: Double = 60
        let frameTime = 1.0 / fps
        let frames = Int(duration * fps)
        
        for frame in 0..<frames {
            let time = Double(frame) * frameTime
            
            DispatchQueue.main.asyncAfter(deadline: .now() + time) {
                for i in 0..<self.particles.count {
                    // Physics: position = initial_velocity * time + 0.5 * gravity * time^2
                    let t = CGFloat(time)
                    
                    // Apply velocity and gravity
                    let newX = self.particles[i].velocity.width * t
                    let newY = self.particles[i].velocity.height * t + 0.5 * gravity * t * t
                    
                    // Update particle
                    self.particles[i].offset = CGSize(width: newX, height: newY)
                    
                    // Rotate particles as they move
                    self.particles[i].rotation += self.particles[i].angularVelocity * frameTime
                    
                    // Fade out over time
                    let fadeStart = 0.3 // Start fading after 30% of animation
                    if time > fadeStart * duration {
                        let fadeProgress = (time - fadeStart * duration) / ((1.0 - fadeStart) * duration)
                        self.particles[i].opacity = 1.0 - fadeProgress
                    }
                    
                    // Scale down slightly as they fade
                    let scaleProgress = time / duration
                    self.particles[i].scale *= (1.0 - CGFloat(scaleProgress) * 0.3)
                }
            }
        }
    }
}

// Preview
#Preview {
    VStack(spacing: 40) {
        HeartParticleAnimationView(isLiked: true)
        
        HeartParticleAnimationView(isLiked: false)
    }
    .padding()
}

