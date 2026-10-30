import SwiftUI

/// Shared feed list component that ensures pixel-perfect consistency across all feed views
struct FeedListView<Content: View>: View {
    let onRefresh: (() async -> Void)?
    let topContentMargin: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        onRefresh: (() async -> Void)?,
        topContentMargin: CGFloat? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.onRefresh = onRefresh
        self.topContentMargin = topContentMargin ?? AppConstants.Layout.listContentTopMargin
        self.content = content
    }

    var body: some View {
        List {
            // Leading empty row. It used to track scroll offset; it stays as a plain row because the
            // negative top content margin was tuned with it in place.
            if topContentMargin != 0 {
                leadingRow
            }

            // Dynamic content
            content()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .listSectionSeparator(.hidden)
        .listSectionSpacing(0) // Remove default section spacing
        .scrollIndicators(.hidden)
        .contentMargins(.top, topContentMargin)
        .refreshable {
            if let onRefresh = onRefresh {
                await onRefresh()
            }
        }
    }

    private var leadingRow: some View {
        Color.clear
            .frame(height: 0)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
    }
}

#Preview {
    FeedListView(onRefresh: nil) {
        ForEach(0..<10, id: \.self) { index in
            HStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading) {
                    Text("Item \(index)")
                        .font(.headline)
                    Text("Sample content")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }
}
