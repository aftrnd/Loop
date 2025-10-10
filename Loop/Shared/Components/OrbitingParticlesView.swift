import SwiftUI

/// Halftone donut pattern with Apple Pay Cash gradient effect
/// - Dots per ring: 18
/// - Rings: 24
/// - Inner radius: 75 pt, ring spacing: 16 pt
/// - Dot size: linear from 10 pt → 0.5 pt
/// - Offset per ring: 10° (perfectly alternated)
/// - Continuous wave animation: stadium wave effect with breathing rhythm
/// - Apple Cash gradient: Distance-based color mapping
///   - Focal point moves with device tilt (accelerometer)
///   - Dots colored based on distance from focal point
///   - Hue range: 0.15-0.85 (orange → yellow → green → cyan → blue → magenta)
///   - Saturation decreases for dots far from focal point (creates fade effect)
struct OrbitingParticlesView: View {
    let baseColor: Color
    let tiltX: Double  // Device tilt left/right (-1 to 1)
    let tiltY: Double  // Device tilt up/down (-1 to 1)
    
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
                    
                    // Focal point parameters based on device tilt
                    let lightX = max(-1, min(1, CGFloat(tiltX)))  // Clamp to -1 to 1
                    let lightY = max(-1, min(1, CGFloat(tiltY)))  // Clamp to -1 to 1
                    
                    // Blur parameters - subtle radial blur from center to edges
                    let maxBlurRadius: CGFloat = 4.0     // Maximum blur at outer edges

                    // Draw rings in groups with increasing blur for depth effect
                    for blurPass in 0..<4 {
                        let blurAmount = CGFloat(blurPass) * (maxBlurRadius / 3.0)
                        
                        // Use drawLayer to isolate blur filter to this pass only
                        context.drawLayer { layerContext in
                            if blurAmount > 0 {
                                layerContext.addFilter(.blur(radius: blurAmount))
                            }
                            
                            for i in 0..<rings {
                                // Only draw rings in this blur pass
                                let ringBlurLevel = Int((CGFloat(i) / CGFloat(rings - 1)) * 3.0)
                                if ringBlurLevel != blurPass { continue }
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
                            
                            // Apple Cash style gradient based on distance from focal point
                            // Focal point moves with device tilt
                            
                            // Map tilt to focal point position on canvas
                            // Larger amplification for more dramatic movement
                            let focalX = cx + CGFloat(tiltX) * 250
                            let focalY = cy + CGFloat(tiltY) * 250
                            
                            // Calculate distance from this dot to focal point
                            let xDist = abs(x - focalX)
                            let yDist = abs(y - focalY)
                            let distanceFromFocal = hypot(xDist, yDist)
                            
                            // Apple Cash uses tight hue range (0.2 to 0.8) creating distinct color bands
                            let minHue: CGFloat = 0.2   // Yellow/green range
                            let maxHue: CGFloat = 0.75  // Blue/purple range
                            let radiusForMinHue: CGFloat = 0
                            let radiusForMaxHue: CGFloat = 280  // Tighter radius = more grouped colors
                            
                            // Linear interpolation helper
                            func mapRange(_ value: CGFloat, _ inMin: CGFloat, _ inMax: CGFloat, _ outMin: CGFloat, _ outMax: CGFloat) -> CGFloat {
                                return ((value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin)
                            }
                            
                            // Calculate base hue from distance
                            let baseHue = max(minHue, min(maxHue, mapRange(distanceFromFocal, radiusForMinHue, radiusForMaxHue, minHue, maxHue)))
                            
                            // Create slight variation for each dot (like Apple's startHue/endHue)
                            // This adds texture while keeping colors grouped
                            let hueVariation: CGFloat = 0.02
                            let hue = baseHue + (CGFloat(j) / CGFloat(M)) * hueVariation
                            
                            // Saturation: Apple Cash uses 0.6 base, desaturates far dots
                            let distanceToBeginDesaturation: CGFloat = 300
                            let distanceToEndDesaturation: CGFloat = 500
                            var saturation: CGFloat = 0.65
                            
                            if distanceFromFocal >= distanceToBeginDesaturation {
                                saturation = mapRange(distanceFromFocal, distanceToBeginDesaturation, distanceToEndDesaturation, 0.65, 0.05)
                                saturation = max(0.05, min(0.65, saturation))
                            }
                            
                            // Lightness: Apple Cash uses 0.7
                            let lightness: CGFloat = 0.7
                            
                            // Convert HSL to RGB (simplified conversion)
                            func hslToRGB(h: CGFloat, s: CGFloat, l: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
                                // Convert HSL to HSB first
                                let brightness = l + s * min(l, 1 - l)
                                let newSaturation = brightness == 0 ? 0 : 2 * (1 - l / brightness)
                                
                                // HSB to RGB
                                let h6 = h * 6
                                let chroma = brightness * newSaturation
                                let x = chroma * (1 - abs((h6.truncatingRemainder(dividingBy: 2)) - 1))
                                let m = brightness - chroma
                                
                                var r: CGFloat = 0
                                var g: CGFloat = 0
                                var b: CGFloat = 0
                                
                                if h6 < 1 {
                                    r = chroma; g = x; b = 0
                                } else if h6 < 2 {
                                    r = x; g = chroma; b = 0
                                } else if h6 < 3 {
                                    r = 0; g = chroma; b = x
                                } else if h6 < 4 {
                                    r = 0; g = x; b = chroma
                                } else if h6 < 5 {
                                    r = x; g = 0; b = chroma
                                } else {
                                    r = chroma; g = 0; b = x
                                }
                                
                                return (r + m, g + m, b + m)
                            }
                            
                            let rgb = hslToRGB(h: hue, s: saturation, l: lightness)
                            
                            let litColor = Color(
                                red: Double(rgb.r),
                                green: Double(rgb.g),
                                blue: Double(rgb.b)
                            )
                            let dotColor = litColor.opacity(opacityGradient)
                            
                            layerContext.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        }
                            }
                        }
                    }
                }
            }
        }
    }
    
}

#Preview {
    OrbitingParticlesView(baseColor: .blue, tiltX: 0.3, tiltY: -0.2)
        .frame(width: 430, height: 932) // iPhone portrait preview (approx 19.5:9)
        .background(Color(red: 0.90, green: 0.94, blue: 0.96))
}

