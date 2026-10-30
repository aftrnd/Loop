import SwiftUI

/// The Loop mark: quarter-circle tiles turning around a center ring, drawn as the app icon's crystal bends them.
/// The artwork is two template vectors in the asset catalog, so the lines follow the foreground style and the ring stays orange.
struct LoopMark: View {
    var body: some View {
        ZStack {
            Image("LoopMarkLines")
                .resizable()
            Image("LoopMarkRing")
                .resizable()
                .foregroundStyle(Color("LoopOrange"))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The mark beside the app's name. The name is set in the system font until the wordmark is designed.
struct LoopWordmark: View {
    var markSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 6) {
            LoopMark()
                .frame(width: markSize, height: markSize)
            Text(AppInfo.name)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppInfo.name)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 32) {
        LoopMark()
            .frame(width: 160, height: 160)
        LoopWordmark()
    }
    .padding()
}
