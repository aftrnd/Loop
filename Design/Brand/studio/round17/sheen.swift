// Soap-film sheen for the echo bubble: a thin band just inside its rim whose hue walks the thin-film sequence
// with the angle and across the band, strongest toward the key light (top left) and its glint (bottom right).
// usage: sheen echo.json out.png size inset sigma strength
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let a = CommandLine.arguments
let j = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: a[1]))) as! [String: Any]
let pts = (j["pts"] as! [[Double]]).map { ($0[0], $0[1]) }
let C = (j["center"] as! [Double])
let N = Int(a[3])!, k = Double(N) / 1024
let inset = Double(a[4])!, sigma = Double(a[5])!, strength = Double(a[6])!
let pale = a.count > 7 ? Double(a[7])! : 0
func inside(_ x: Double, _ y: Double) -> Bool {
    var c = false; var jj = pts.count - 1
    for i in 0..<pts.count { let (xi, yi) = pts[i], (xj, yj) = pts[jj]
        if (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi { c.toggle() }; jj = i }
    return c
}
// thin-film palette: a smooth loop through magenta, gold, green-cyan, blue (sRGB 0...1)
let stops: [(Double, Double, Double)] = [(0.93, 0.42, 0.85), (1.0, 0.78, 0.38), (0.55, 0.92, 0.70), (0.38, 0.72, 1.0), (0.62, 0.50, 1.0)]
func film(_ t: Double) -> (Double, Double, Double) {
    let u = (t.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * Double(stops.count)
    let i = Int(u) % stops.count, f = u - Double(Int(u)), b = stops[(i + 1) % stops.count]
    let s = f * f * (3 - 2 * f), p = stops[i]
    let c = (p.0 + (b.0 - p.0) * s, p.1 + (b.1 - p.1) * s, p.2 + (b.2 - p.2) * s)
    return (c.0 + (1 - c.0) * pale, c.1 + (1 - c.1) * pale, c.2 + (1 - c.2) * pale)
}
func lit(_ ang: Double) -> Double {
    let tl = pow(max(0, cos(ang - 225 * .pi / 180)), 2.0)
    let br = 0.6 * pow(max(0, cos(ang - 45 * .pi / 180)), 3.0)
    return min(1, 0.06 + tl + br)
}
var px = [UInt8](repeating: 0, count: N * N * 4)
let xs = pts.map { $0.0 }, ys = pts.map { $0.1 }
let x0 = Int((xs.min()! - 4) * k), x1 = Int((xs.max()! + 4) * k), y0 = Int((ys.min()! - 4) * k), y1 = Int((ys.max()! + 4) * k)
px.withUnsafeMutableBufferPointer { buf in
    DispatchQueue.concurrentPerform(iterations: y1 - y0) { dy in
        let py = y0 + dy
        for pxx in x0..<x1 {
            var r = 0.0, g = 0.0, b = 0.0, al = 0.0
            for sy in 0..<3 { for sx in 0..<3 {          // 3 x 3 supersampling
                let x = (Double(pxx) + (Double(sx) + 0.5) / 3) / k, y = (Double(py) + (Double(sy) + 0.5) / 3) / k
                guard inside(x, y) else { continue }
                var d2 = Double.infinity
                for (qx, qy) in pts { let e = (qx - x) * (qx - x) + (qy - y) * (qy - y); if e < d2 { d2 = e } }
                let d = d2.squareRoot()
                guard d < inset + 4 * sigma else { continue }
                let ang = atan2(y - C[1], x - C[0])
                let w = exp(-pow((d - inset) / sigma, 2) / 2) * lit(ang) * strength
                let c = film(ang / (2 * .pi) * 1.25 + d / (inset * 3.2) + 0.15)
                r += c.0 * w; g += c.1 * w; b += c.2 * w; al += w
            }}
            let A = min(1, al / 9)
            if A <= 0 { continue }
            let i = (py * N + pxx) * 4
            buf[i] = UInt8(min(255, r / 9 * 255)); buf[i + 1] = UInt8(min(255, g / 9 * 255)); buf[i + 2] = UInt8(min(255, b / 9 * 255))
            buf[i + 3] = UInt8(A * 255)
        }
    }
}
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let img = CGImage(width: N, height: N, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: N * 4, space: cs,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: CGDataProvider(data: Data(px) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
