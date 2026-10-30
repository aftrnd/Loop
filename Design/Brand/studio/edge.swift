import CoreGraphics
import Foundation
import ImageIO
// edge.swift img.png : for each row, the sub-pixel x where alpha crosses 0.5 on the left edge; prints image size first
let a = CommandLine.arguments
let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!, 0, nil)!
let w = img.width, h = img.height
var data = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
print(w, h)
for y in 0..<h {
    var prev = 0.0
    var found = -1.0
    for x in 0..<w {
        let al = Double(data[(y * w + x) * 4 + 3]) / 255
        if al >= 0.5 { found = x == 0 ? 0 : Double(x - 1) + (0.5 - prev) / (al - prev) + 0.5; break }
        prev = al
    }
    print(y, String(format: "%.3f", found))
}
