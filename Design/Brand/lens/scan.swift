import CoreGraphics
import Foundation
import ImageIO
// scan.swift img.png angleDeg : dark crossings along a ray from the center (512,512), as radii
let a = CommandLine.arguments
let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!, 0, nil)!
let w = img.width, h = img.height
var data = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
let ang = Double(a[2])! * .pi / 180
var inDark = false, start = 0.0, out: [String] = []
var r = 0.0
while r < 440 {
    let x = 512 + r * cos(ang), y = 512 + r * sin(ang)
    let xi = Int(x.rounded()), yi = Int(y.rounded())
    let i = (yi * w + xi) * 4
    let lum = (Int(data[i]) + Int(data[i + 1]) + Int(data[i + 2])) / 3
    if lum < 128 && !inDark { inDark = true; start = r }
    if lum >= 128 && inDark { inDark = false; out.append(String(format: "%.1f", (start + r) / 2)) }
    r += 0.25
}
print(out.joined(separator: " "))
