import SwiftUI

struct LiquidGlassModifier: ViewModifier {
    let intensity: Double
    
    init(intensity: Double = 0.1) {
        self.intensity = intensity
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            )
    }
}

extension View {
    func liquidGlass(intensity: Double = 0.1) -> some View {
        modifier(LiquidGlassModifier(intensity: intensity))
    }
}
