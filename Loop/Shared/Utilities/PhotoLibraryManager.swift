import Photos
import PhotosUI
import SwiftUI

/// Manages photo library permissions and access
class PhotoLibraryManager {
    static let shared = PhotoLibraryManager()
    
    private init() {}
    
    /// Request photo library access with modern iOS 18+ handling
    /// - Returns: true if access is granted (full or limited), false if denied
    @MainActor
    func requestPhotoLibraryAccess() async -> Bool {
        // Use the modern async API for iOS 18+
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            return true
            
        case .denied, .restricted:
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// Get current authorization status (for checking without requesting)
    var currentAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    /// Check if user has limited photo access and prompt them to change to full access
    @MainActor
    func promptForFullAccessIfLimited() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if status == .limited {
            // Present the limited library picker to allow user to select more photos
            // or change to full access
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: getRootViewController())
        }
    }
    
    /// Check if we have full access (not limited)
    var hasFullAccess: Bool {
        currentAuthorizationStatus == .authorized
    }
    
    /// Check if we have limited access
    var hasLimitedAccess: Bool {
        currentAuthorizationStatus == .limited
    }
    
    /// Check if we have any level of access
    var hasAnyAccess: Bool {
        let status = currentAuthorizationStatus
        return status == .authorized || status == .limited
    }
    
    // Helper to get root view controller
    private func getRootViewController() -> UIViewController {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return UIViewController()
        }
        
        var topController = rootViewController
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        
        return topController
    }
}

