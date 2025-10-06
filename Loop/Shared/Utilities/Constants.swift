import Foundation

struct AppConstants {
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let spacing: CGFloat = 8
    }
    
    struct Layout {
        // Standard list content margin to align with navigation bar
        static let listContentTopMargin: CGFloat = -32
        // Adjusted margin for Home feed to match Messages positioning
        static let homeListContentTopMargin: CGFloat = -27
    }
    
    struct Animation {
        static let defaultDuration: Double = 0.3
        static let springDamping: Double = 0.8
    }
}
