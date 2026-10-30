import SwiftUI

/// The Loop wordmark: "loop" set in Geist at weight 650 and outlined, so it draws the same at every size.
/// The artwork is a template vector in the asset catalog cropped to the ink, so it follows the foreground style.
struct LoopWordmark: View {
    /// Height of the l's ascender in points; 17 matches the toolbar size on the brand proof.
    var ascender: CGFloat = 17

    var body: some View {
        Image("LoopWordmark")
            .resizable()
            .scaledToFit()
            .frame(height: ascender * Self.heightPerAscender)
            .foregroundStyle(.primary)
            .accessibilityLabel(AppInfo.name)
            .accessibilityAddTraits(.isHeader)
    }

    /// Ink height (ascender 710 plus descender 150, in font units) over the ascender.
    private static let heightPerAscender: CGFloat = 860 / 710
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        LoopWordmark(ascender: 64)
        LoopWordmark()
    }
    .padding()
}
