import SwiftUI

extension View {
    /// Applies a consistent padding style across the app
    func appPadding() -> some View {
        self.padding(.horizontal, 16)
    }
    
    /// Applies a consistent corner radius style across the app
    func appCornerRadius() -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// Backwards-compatible interactive keyboard dismissal.
    /// Uses `.scrollDismissesKeyboard(.interactively)` when available.
    @ViewBuilder
    func interactiveKeyboardDismiss() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}
