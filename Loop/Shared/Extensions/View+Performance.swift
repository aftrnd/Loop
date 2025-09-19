import SwiftUI

extension View {
    /// Lightweight glass effect alternative for better performance
    func lightGlassEffect<S: Shape>(_ style: Material = .regular, in shape: S) -> some View {
        self.background(
            shape
                .fill(.ultraThinMaterial)
                .opacity(0.8)
        )
    }
    
    /// Performance-optimized glass effect that only applies on non-critical views
    func optimizedGlassEffect<S: Shape>(_ style: Material = .regular, in shape: S) -> some View {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            // Use simple background in low power mode
            return AnyView(
                self.background(
                    shape
                        .fill(Color(.systemGray6).opacity(0.6))
                )
            )
        } else {
            // Use material effect when performance allows
            return AnyView(
                self.background(
                    shape
                        .fill(.ultraThinMaterial)
                        .opacity(0.9)
                )
            )
        }
    }
    
    /// Throttled modifier to reduce excessive updates with proper state management
    func throttled<T: Equatable>(
        _ value: T,
        delay: TimeInterval = 0.1,
        perform action: @escaping (T) -> Void
    ) -> some View {
        self.modifier(ThrottledModifier(value: value, delay: delay, action: action))
    }
}

// MARK: - Throttled Modifier Implementation
struct ThrottledModifier<T: Equatable>: ViewModifier {
    let value: T
    let delay: TimeInterval
    let action: (T) -> Void
    
    @State private var lastExecutionTime: Date = .distantPast
    @State private var pendingWorkItem: DispatchWorkItem?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: value) { _, newValue in
                let now = Date()
                let timeSinceLastExecution = now.timeIntervalSince(lastExecutionTime)
                
                // Cancel any pending work
                pendingWorkItem?.cancel()
                
                if timeSinceLastExecution >= delay {
                    // Execute immediately
                    action(newValue)
                    lastExecutionTime = now
                } else {
                    // Schedule for later
                    let workItem = DispatchWorkItem {
                        action(newValue)
                        lastExecutionTime = Date()
                    }
                    pendingWorkItem = workItem
                    
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + (delay - timeSinceLastExecution),
                        execute: workItem
                    )
                }
            }
    }
}
