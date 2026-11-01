import SwiftUI

/// A topic account's avatar: the avatar squircle in the topic's color with its symbol, and a small star in the
/// corner that marks its posts as written by AI.
struct TopicAvatar: View {
    let topic: LoopTopic
    let size: CGFloat

    /// The star's disc, sized for the feed's 56pt avatar and scaled with it
    private var badgeSize: CGFloat {
        size * 20 / 56
    }

    var body: some View {
        AvatarShape()
            .fill(Color(hex: topic.color) ?? Color(.systemGray3))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: topic.symbol)
                    .font(.system(size: size * 3 / 7, weight: .semibold))
                    .foregroundStyle(Color(hex: topic.ink) ?? .white)
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: badgeSize / 2, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: badgeSize, height: badgeSize)
                    .background(Circle().fill(Color.primary))
                    // A ring of the page around the star, so it reads as its own mark over the squircle's corner
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: badgeSize / 5, y: badgeSize / 5)
            }
            .accessibilityElement()
            .accessibilityLabel("Topic account, written by AI")
    }
}

private extension Color {
    /// A color from `#RRGGBB`, or nil if the string isn't one
    init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

#Preview {
    HStack(spacing: 20) {
        TopicAvatar(topic: LoopTopic(id: "steelers", symbol: "football.fill", color: "#101820", ink: "#FFB612"), size: 56)
        TopicAvatar(topic: LoopTopic(id: "politics", symbol: "building.columns.fill", color: "#283F85", ink: "#FFFFFF"), size: 56)
    }
    .padding()
}
