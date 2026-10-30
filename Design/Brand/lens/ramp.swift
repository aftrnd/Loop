import CoreGraphics
import Foundation
import ImageIO
// ramp.swift img.png angleDeg : luminance along a ray, as source radius = lum * 256 / 255
let a = CommandLine.arguments
let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!, 0, nil)!
let w = img.width, h = img.height, S = Double(w) / 1024
var data = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
let ang = Double(a[2])! * .pi / 180
var d = 0.0
var line: [String] = []
while d <= 240 {
    let x = Int(((512 + d * cos(ang)) * S).rounded()), y = Int(((512 + d * sin(ang)) * S).rounded())
    let i = (y * w + x) * 4
    let lum = (Double(data[i]) + Double(data[i + 1]) + Double(data[i + 2])) / 3
    line.append(String(format: "%.1f:%.1f", d, lum * 256 / 255))
    d += 4
}
print(line.joined(separator: " "))
