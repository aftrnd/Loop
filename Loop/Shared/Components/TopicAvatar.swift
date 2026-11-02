import SwiftUI

/// A topic account's avatar: the avatar squircle with the topic's symbol. A team wears its own colors, swapped in dark
/// mode so its light color is the tile there; every other topic is drawn in ink.
struct TopicAvatar: View {
    let topic: LoopTopic
    let size: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = colors
        AvatarShape()
            .fill(colors.tile)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: topic.symbol)
                    .font(.system(size: size * 3 / 7, weight: .semibold))
                    .foregroundStyle(colors.symbol)
            }
            .accessibilityElement()
            .accessibilityLabel("Topic account")
    }

    /// The squircle's fill and the symbol's color
    private var colors: (tile: Color, symbol: Color) {
        if topic.isTeam, let color = Color(hex: topic.color), let ink = Color(hex: topic.ink) {
            return colorScheme == .dark ? (ink, color) : (color, ink)
        }
        return (.primary, Color(.systemBackground))
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
        TopicAvatar(topic: LoopTopic(id: "steelers", symbol: "football.fill", color: "#101820", ink: "#FFB612", style: "team"), size: 56)
        TopicAvatar(topic: LoopTopic(id: "nfl", symbol: "trophy.fill", color: "#013369", ink: "#FFFFFF", style: "team"), size: 56)
        TopicAvatar(topic: LoopTopic(id: "politics", symbol: "building.columns.fill", color: "#283F85", ink: "#FFFFFF", layout: "article"), size: 56)
    }
    .padding()
}
