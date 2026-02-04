import UIKit

extension UIImage {
    /// Resizes image to fit within max dimensions while maintaining aspect ratio
    /// Uses high quality rendering for crisp results
    func resized(toMaxDimensions maxSize: CGSize) -> UIImage? {
        // Calculate new size maintaining aspect ratio
        let aspectWidth = maxSize.width / size.width
        let aspectHeight = maxSize.height / size.height
        let aspectRatio = min(aspectWidth, aspectHeight)
        
        // If image is already smaller, return original
        if aspectRatio >= 1.0 {
            return self
        }
        
        let newSize = CGSize(
            width: size.width * aspectRatio,
            height: size.height * aspectRatio
        )
        
        // Use UIGraphicsImageRenderer for high quality, efficient rendering
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // Use 1x scale for consistent sizing
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        
        return renderer.image { context in
            // Draw with high quality interpolation
            context.cgContext.interpolationQuality = .high
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Resizes image for avatar use (512x512 max)
    func resizedForAvatar() -> UIImage? {
        resized(toMaxDimensions: CGSize(width: 512, height: 512))
    }
    
    /// Resizes image for banner use (1920x1080 max)
    func resizedForBanner() -> UIImage? {
        resized(toMaxDimensions: CGSize(width: 1920, height: 1080))
    }
    
    /// Resizes image for post media (2048x2048 max)
    func resizedForPost() -> UIImage? {
        resized(toMaxDimensions: CGSize(width: 2048, height: 2048))
    }
}
