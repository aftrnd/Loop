import SwiftUI

struct HeartParticle: Identifiable {
    let id = UUID()
    var offset: CGSize
    let initialOffset: CGSize // Random starting position (preserved)
    var velocity: CGSize
    var scale: CGFloat
    var opacity: Double
    var rotation: Double
    var angularVelocity: Double
}

struct ParticleBatch: Identifiable {
    let id = UUID()
    var particles: [HeartParticle]
}

struct HeartParticleAnimationView: View {
    @State private var particleBatches: [UUID: [HeartParticle]] = [:] // ID -> Particles
    @State private var lastTriggerID: UUID?
    
    var iconSize: CGFloat = 18
    var triggerID: UUID
    
    var body: some View {
        ZStack {
            // Render all particle batches (allows overlapping animations)
            ForEach(Array(particleBatches.keys), id: \.self) { batchID in
                if let particles = particleBatches[batchID] {
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
            }
        }
        .allowsHitTesting(false)
        .onChange(of: triggerID) { _, newID in
            // Only trigger if the ID actually changed
            guard newID != lastTriggerID else { return }
            lastTriggerID = newID
            triggerAnimation()
        }
    }
    
    private func triggerAnimation() {
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
            
            // Random starting position within a few points of center
            // Adds organic variation to the explosion (each particle starts from a slightly different spot)
            let randomOffsetX = CGFloat.random(in: -4...4)
            let randomOffsetY = CGFloat.random(in: -4...4)
            
            // Shift origin down by 2 points to better center on heart icon
            let centeredOffsetY = randomOffsetY + 2
            let initialRandomOffset = CGSize(width: randomOffsetX, height: centeredOffsetY)
            
            let particle = HeartParticle(
                offset: initialRandomOffset, // Start at random position
                initialOffset: initialRandomOffset, // Store for physics calculations
                velocity: CGSize(width: velocityX, height: velocityY),
                scale: CGFloat.random(in: 0.6...1.0),
                opacity: 1.0,
                rotation: Double.random(in: -180...180),
                angularVelocity: Double.random(in: -360...360)
            )
            newParticles.append(particle)
        }
        
        // Create unique ID for this batch
        let batchID = UUID()
        particleBatches[batchID] = newParticles
        
        // Physics-based animation with gravity
        animateParticlesWithGravity(batchID: batchID)
        
        // Clear this batch after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.particleBatches.removeValue(forKey: batchID)
        }
    }
    
    private func animateParticlesWithGravity(batchID: UUID) {
        let gravity: CGFloat = 250 // Pixels per second squared
        let duration: Double = 0.9
        let fps: Double = 60
        let frameTime = 1.0 / fps
        let frames = Int(duration * fps)
        
        for frame in 0..<frames {
            let time = Double(frame) * frameTime
            
            DispatchQueue.main.asyncAfter(deadline: .now() + time) { [self] in
                // Check if batch still exists (might have been removed)
                guard var particles = self.particleBatches[batchID] else { return }
                
                for i in 0..<particles.count {
                    // Physics: position = initial_velocity * time + 0.5 * gravity * time^2
                    let t = CGFloat(time)
                    
                    // Calculate physics-based displacement from origin
                    let physicsX = particles[i].velocity.width * t
                    let physicsY = particles[i].velocity.height * t + 0.5 * gravity * t * t
                    
                    // Add initial random offset to physics position
                    let newX = particles[i].initialOffset.width + physicsX
                    let newY = particles[i].initialOffset.height + physicsY
                    
                    // Update particle position
                    particles[i].offset = CGSize(width: newX, height: newY)
                    
                    // Rotate particles as they move
                    particles[i].rotation += particles[i].angularVelocity * frameTime
                    
                    // Fade out over time
                    let fadeStart = 0.3 // Start fading after 30% of animation
                    if time > fadeStart * duration {
                        let fadeProgress = (time - fadeStart * duration) / ((1.0 - fadeStart) * duration)
                        particles[i].opacity = 1.0 - fadeProgress
                    }
                    
                    // Scale down slightly as they fade
                    let scaleProgress = time / duration
                    particles[i].scale *= (1.0 - CGFloat(scaleProgress) * 0.3)
                }
                
                // Write back the updated particles
                self.particleBatches[batchID] = particles
            }
        }
    }
}

// Preview
#Preview {
    VStack(spacing: 40) {
        HeartParticleAnimationView(triggerID: UUID())
        
        HeartParticleAnimationView(triggerID: UUID())
    }
    .padding()
}

