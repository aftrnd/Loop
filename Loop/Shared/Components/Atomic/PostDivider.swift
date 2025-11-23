import SwiftUI

/// Atomic component: Post divider
/// Single source of truth for dividers between posts
struct PostDivider: View {
    var body: some View {
        Rectangle()
            .fill(CardLayoutConstants.dividerColor)
            .frame(height: CardLayoutConstants.dividerHeight)
            .padding(.leading, CardLayoutConstants.horizontalPadding)
            .padding(.trailing, CardLayoutConstants.horizontalPadding)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        Color.blue.frame(height: 100)
        PostDivider()
        Color.green.frame(height: 100)
        PostDivider()
        Color.orange.frame(height: 100)
    }
}




