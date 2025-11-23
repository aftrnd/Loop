import SwiftUI

/// Global manager for displaying photos in full screen
/// Manages state at app root level to ensure true full-screen presentation
@Observable
class PhotoViewerManager {
    var isPresented: Bool = false
    var media: [LoopMedia] = []
    var startingIndex: Int = 0
    var backgroundOpacity: Double = 0.0
    
    /// Show photo viewer with given media
    func show(media: [LoopMedia], startingAt index: Int) {
        self.media = media
        self.startingIndex = index
        self.isPresented = true
    }
    
    /// Dismiss photo viewer
    func dismiss() {
        self.isPresented = false
    }
}




