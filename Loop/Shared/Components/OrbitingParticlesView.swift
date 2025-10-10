import SwiftUI

/// Vogel spiral (phyllotaxis) pattern - like sunflower seeds
/// Creates a beautiful radial symmetry with golden angle spacing
struct OrbitingParticlesView: View {
    // MARK: - Configuration
    
    /// Easily adjustable pattern configuration
    struct Config {
        // Pattern Structure
        var spacingConstant: Double = 15        // c: Controls overall scale/spread
        var dotCount: Int = 1100                // N: Total number of dots to render
        var ringCenterRadius: Double = 180      // R₀: Where the ring is centered (px)
        var ringThickness: Double = 60          // σ: Width of the Gaussian ring
        var maxDotSize: Double = 6.5            // ρ_max: Largest dot radius (px)
        var centerBoostAmount: Double = 1.5     // Extra size boost for center dots
        
        // Animation Speeds
        var rotationSpeed: Double = 0.02        // Rotation speed (rad/s) - lower = slower
        var breathingSpeed: Double = 0.4        // Breathing cycle speed (rad/s)
        var breathingAmount: Double = 0.05      // Breathing intensity (0.05 = ±5%)
        var waveSpeed: Double = 1.2             // Traveling wave speed (rad/s)
        var waveAmount: Double = 0.12           // Wave intensity (0.12 = ±12%)
        
        // Visual
        var alignToTop: Bool = true             // Align a dot to 12 o'clock
    }
    
    // Active configuration - modify these values to change the pattern!
    private let config = Config()
    
    // Golden angle constant: φ = π(3-√5) ≈ 2.39996323
    private let goldenAngle = Double.pi * (3.0 - sqrt(5.0))
    
    // Rotation offset to align pattern
    private var rotationOffset: Double {
        config.alignToTop ? -Double.pi / 2.0 : 0
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            ZStack {
                ForEach(0..<config.dotCount, id: \.self) { n in
                    let dot = calculateDot(index: n + 1, time: time)
                    
                    if dot.size > 0.5 { // Only show dots with visible size
                        Circle()
                            .fill(Color.primary)
                            .frame(width: dot.size * 2, height: dot.size * 2)
                            .offset(x: dot.x, y: dot.y)
                    }
                }
            }
        }
    }
    
    // MARK: - Vogel Spiral Calculation with Animation
    
    /// Calculate position and size for dot n using Vogel spiral with subtle pulsating animation
    private func calculateDot(index n: Int, time: TimeInterval) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        let nDouble = Double(n)
        
        // 1. Calculate radial distance with subtle breathing: r_n = c√n · (1 + breathing)
        // Keep circles perfectly round by only scaling radially
        let breathe = sin(time * config.breathingSpeed) * config.breathingAmount
        let r = config.spacingConstant * sqrt(nDouble) * (1.0 + breathe)
        
        // 2. Calculate angle with slow rotation: θ_n = n·φ + offset + slow rotation
        let slowRotation = time * config.rotationSpeed
        let theta = nDouble * goldenAngle + rotationOffset + slowRotation
        
        // 3. Convert to Cartesian coordinates
        let x = r * cos(theta)
        let y = r * sin(theta)
        
        // 4. Calculate dot size with Gaussian + center boost + traveling wave
        // Base Gaussian: ρ_n = ρ_max · exp(-(r_n - R₀)²/(2σ²))
        let diff = r - config.ringCenterRadius
        let exponent = -(diff * diff) / (2.0 * config.ringThickness * config.ringThickness)
        let gaussianSize = config.maxDotSize * exp(exponent)
        
        // Add size boost for dots near center (makes innermost dots larger)
        let centerBoost = exp(-(r * r) / 8000.0) * config.centerBoostAmount
        
        // Add traveling wave that ripples around the circle
        let angularWave = sin(theta * 3.0 + time * config.waveSpeed) * config.waveAmount
        let waveModulation = 1.0 + angularWave
        
        let baseSize = gaussianSize + centerBoost
        let size = baseSize * waveModulation
        
        return (CGFloat(x), CGFloat(y), CGFloat(size))
    }
}

// MARK: - Preview

#Preview("Orbiting Particles") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()
        
        ZStack {
            // Background circle (like in the welcome screen)
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 120, height: 120)
            
            // Orbiting particles
            OrbitingParticlesView()
            
            // Icon in center
            Image(systemName: "message.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

#Preview("Full Welcome Layout") {
    VStack(spacing: 24) {
        Spacer()
        
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 120, height: 120)
            
            OrbitingParticlesView()
            
            Image(systemName: "message.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.primary)
        }
        
        VStack(spacing: 8) {
            Text("Welcome to Loop")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Enter your phone number to get started")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        
        Spacer()
    }
    .padding()
}

