import SwiftUI

/// Halftone donut drawn with concentric rings.
/// - Dots per ring: M = 18
/// - Rings: 24
/// - Inner radius: 75 pt, ring spacing: 16 pt
/// - Dot size: linear from 10 pt → 0.5 pt
/// - Offset per ring: 10° (perfectly alternated)
/// - Continuous wave animation: stadium wave effect with breathing rhythm
/// - Dynamic gradient: dots change color to match accent color
struct OrbitingParticlesView: View {
    // Use Color.primary to auto-adapt: white in dark mode, black in light mode
    var accentColor: Color = .primary
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            GeometryReader { geo in
                let size = geo.size
                let cx = size.width / 2
                let top: CGFloat = 0
                let bottom = size.height - 0
                let cy = (top + bottom) / 2
                Canvas { context, _ in
                    let M = 18
                    let rings = 24
                    let innerR: CGFloat = 75
                    let step: CGFloat = 16
                    let maxDot: CGFloat = 10
                    let minDot: CGFloat = 0.5
                    let offset = 10.0 * CGFloat.pi / 180
                    
                    // Animation parameters
                    let waveSpeed: CGFloat = 1.57        // Radial wave speed - breathing rate (π/2 for 4s cycle)
                    let waveFrequency: CGFloat = 0.018   // Wave frequency - tuned for continuous visible wave crest

                    for i in 0..<rings {
                        let r = innerR + CGFloat(i) * step
                        let t = CGFloat(i) / CGFloat(rings - 1)
                        
                        // Base size decreases linearly for outer rings
                        let baseSize = maxDot + t * (minDot - maxDot)
                        let base = CGFloat(i) * offset
                        
                        // Calculate gradient opacity based on ring position
                        // Inner rings are more vibrant, outer rings fade
                        let opacityGradient = 1.0 - (t * 0.6) // Fades from 1.0 to 0.4
                        
                        for j in 0..<M {
                            let theta = 2 * CGFloat.pi * CGFloat(j) / CGFloat(M) + base
                            
                            // No rotation – dots remain fixed in angle
                            let animatedTheta = theta
                            
                            // Wave effect: synchronized with breathing - icon creates the wave
                            // Phase calculation synced so wave emanates from center when icon expands
                            let wavePhase = sin(r * waveFrequency - CGFloat(time) * waveSpeed + CGFloat.pi / 2.0)
                            
                            // Map to 0-1 range with smooth transitions
                            // This keeps a visible wave crest always present in the pattern
                            let normalizedWave = (wavePhase + 1.0) / 2.0 // 0 to 1
                            
                            // Apply easing to make wave crest sharper and more visible
                            let easedWave = pow(normalizedWave, 2.5) // Higher power = sharper, more visible crest
                            
                            // Dots transition smoothly from minDot to baseSize as wave passes
                            let dot = minDot + (baseSize - minDot) * easedWave
                            
                            let x = cx + r * cos(animatedTheta)
                            let y = cy + r * sin(animatedTheta)
                            let rect = CGRect(x: x - dot/2, y: y - dot/2, width: dot, height: dot)
                            
                            // Apply accent color with gradient opacity
                            let dotColor = accentColor.opacity(opacityGradient)
                            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    OrbitingParticlesView()
        .frame(width: 430, height: 932) // iPhone portrait preview (approx 19.5:9)
        .background(Color(red: 0.90, green: 0.94, blue: 0.96))
}

