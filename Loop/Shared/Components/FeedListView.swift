import SwiftUI

/// Shared feed list component that ensures pixel-perfect consistency across all feed views
struct FeedListView<Content: View>: View {
    let coordinateSpaceName: String
    let onRefresh: (() async -> Void)?
    @Binding var scrollOffset: CGFloat
    @Binding var contentHeight: CGFloat
    @Binding var scrollViewHeight: CGFloat
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        GeometryReader { scrollGeometry in
            List {
                // Scroll sentinel for tracking
                scrollSentinel
                
                // Dynamic content
                content()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .listSectionSeparator(.hidden)
            .coordinateSpace(name: coordinateSpaceName)
            .scrollIndicators(.hidden)
            .contentMargins(.top, AppConstants.Layout.listContentTopMargin)
            .refreshable {
                if let onRefresh = onRefresh {
                    await onRefresh()
                }
            }
            .onAppear {
                scrollViewHeight = scrollGeometry.size.height
            }
            .onChange(of: scrollGeometry.size.height) { _, newValue in
                scrollViewHeight = newValue
            }
        }
    }
    
    private var scrollSentinel: some View {
        GeometryReader { geo in
            let topMinY = geo.frame(in: .named(coordinateSpaceName)).minY
            Color.clear
                .onChange(of: topMinY) { _, newValue in
                    let offset = max(0, -newValue)
                    scrollOffset = offset
                }
        }
        .frame(height: 0)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    @State var scrollOffset: CGFloat = 0
    @State var contentHeight: CGFloat = 0
    @State var scrollViewHeight: CGFloat = 0
    
    return FeedListView(
        coordinateSpaceName: "preview",
        onRefresh: nil,
        scrollOffset: $scrollOffset,
        contentHeight: $contentHeight,
        scrollViewHeight: $scrollViewHeight
    ) {
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
