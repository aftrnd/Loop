import CoreGraphics
import Foundation
import ImageIO
// table.swift ramp.png : source radius for display radius 0..240 step 0.5, averaged over 8 directions
let a = CommandLine.arguments
let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!, 0, nil)!
let w = img.width, h = img.height, S = Double(w) / 1024
var data = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
func lum(_ x: Double, _ y: Double) -> Double {
    let x0 = Int(floor(x)), y0 = Int(floor(y)); let fx = x - Double(x0), fy = y - Double(y0)
    func p(_ xi: Int, _ yi: Int) -> Double { let i = (yi * w + xi) * 4; return (Double(data[i]) + Double(data[i + 1]) + Double(data[i + 2])) / 3 }
    return p(x0, y0) * (1 - fx) * (1 - fy) + p(x0 + 1, y0) * fx * (1 - fy) + p(x0, y0 + 1) * (1 - fx) * fy + p(x0 + 1, y0 + 1) * fx * fy
}
var d = 0.0
var out: [String] = []
while d <= 240.001 {
    var acc = 0.0
    for k in 0..<8 { let ang = Double(k) * .pi / 4 + .pi / 8; acc += lum((512 + d * cos(ang)) * S, (512 + d * sin(ang)) * S) }
    out.append(String(format: "%.1f %.3f", d, acc / 8 * 256 / 255))
    d += 0.5
}
print(out.joined(separator: "\n"))
