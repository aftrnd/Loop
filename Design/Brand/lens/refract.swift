import CoreGraphics
import Foundation
import ImageIO
// refract.swift source.png table.txt R out.txt
// Applies the measured radial lens map (display radius -> source radius) inside radius R,
// then traces the result with marching squares and prints an SVG path in 1024 units.
let a = CommandLine.arguments
let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!, 0, nil)!
let N = img.width, U = Double(N) / 1024
var raw = [UInt8](repeating: 0, count: N * N * 4)
let ctx = CGContext(data: &raw, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: N, height: N))
var src = [Float](repeating: 0, count: N * N)
for i in 0..<(N * N) { src[i] = 1 - Float(Int(raw[i * 4]) + Int(raw[i * 4 + 1]) + Int(raw[i * 4 + 2])) / 765 }
var table: [Double] = []
for line in try! String(contentsOfFile: a[2], encoding: .utf8).split(separator: "\n") { table.append(Double(line.split(separator: " ")[1])!) }
let R = Double(a[3])!, inner = 176.0
func s(_ d: Double) -> Double {
    if d < inner || d >= R - 0.5 { return d }
    let k = d * 2; let i = Int(k); let f = k - Double(i)
    return table[i] * (1 - f) + table[min(i + 1, table.count - 1)] * f
}
func sample(_ x: Double, _ y: Double) -> Float {
    let px = x * U - 0.5, py = y * U - 0.5
    let x0 = Int(floor(px)), y0 = Int(floor(py)); let fx = Float(px - Double(x0)), fy = Float(py - Double(y0))
    if x0 < 0 || y0 < 0 || x0 + 1 >= N || y0 + 1 >= N { return 0 }
    return src[y0 * N + x0] * (1 - fx) * (1 - fy) + src[y0 * N + x0 + 1] * fx * (1 - fy) + src[(y0 + 1) * N + x0] * (1 - fx) * fy + src[(y0 + 1) * N + x0 + 1] * fx * fy
}
var v = [Float](repeating: 0, count: N * N)
for j in 0..<N { for i in 0..<N {
    let x = (Double(i) + 0.5) / U, y = (Double(j) + 0.5) / U
    let dx = x - 512, dy = y - 512, d = (dx * dx + dy * dy).squareRoot()
    if d > 1e-6 && d < R { let k = s(d) / d; v[j * N + i] = sample(512 + dx * k, 512 + dy * k) } else { v[j * N + i] = src[j * N + i] }
} }
// marching squares
@inline(__always) func val(_ i: Int, _ j: Int) -> Float { v[j * N + i] }
func H(_ i: Int, _ j: Int) -> Int { (j * N + i) * 2 }
func V(_ i: Int, _ j: Int) -> Int { (j * N + i) * 2 + 1 }
var pos: [Int: (Double, Double)] = [:]
var adj: [Int: [Int]] = [:]
func pt(_ e: Int) -> (Double, Double) {
    if let p = pos[e] { return p }
    let base = e / 2, i = base % N, j = base / N
    let (va, vb, ax, ay, bx, by): (Float, Float, Double, Double, Double, Double) = e % 2 == 0 ? (val(i, j), val(i + 1, j), Double(i), Double(j), Double(i + 1), Double(j)) : (val(i, j), val(i, j + 1), Double(i), Double(j), Double(i), Double(j + 1))
    let t = Double((0.5 - va) / (vb - va))
    let p = (((ax + (bx - ax) * t) + 0.5) / U, ((ay + (by - ay) * t) + 0.5) / U)
    pos[e] = p; return p
}
func link(_ e1: Int, _ e2: Int) { _ = pt(e1); _ = pt(e2); adj[e1, default: []].append(e2); adj[e2, default: []].append(e1) }
for j in 0..<(N - 1) { for i in 0..<(N - 1) {
    let a0 = val(i, j) >= 0.5, b0 = val(i + 1, j) >= 0.5, c0 = val(i + 1, j + 1) >= 0.5, d0 = val(i, j + 1) >= 0.5
    let c = (a0 ? 8 : 0) | (b0 ? 4 : 0) | (c0 ? 2 : 0) | (d0 ? 1 : 0)
    if c == 0 || c == 15 { continue }
    let T = H(i, j), Rt = V(i + 1, j), B = H(i, j + 1), L = V(i, j)
    let center = (val(i, j) + val(i + 1, j) + val(i + 1, j + 1) + val(i, j + 1)) / 4 >= 0.5
    switch c {
    case 1, 14: link(L, B)
    case 2, 13: link(B, Rt)
    case 3, 12: link(L, Rt)
    case 4, 11: link(T, Rt)
    case 6, 9: link(T, B)
    case 7, 8: link(L, T)
    case 5: if center { link(L, T); link(B, Rt) } else { link(L, B); link(T, Rt) }
    case 10: if center { link(L, B); link(T, Rt) } else { link(L, T); link(B, Rt) }
    default: break
    }
} }
// walk loops
var seen = Set<Int>()
var loops: [[(Double, Double)]] = []
for (start, _) in adj where !seen.contains(start) {
    var loop: [(Double, Double)] = []
    var prev = -1, cur = start
    while !seen.contains(cur) {
        seen.insert(cur); loop.append(pos[cur]!)
        let n = adj[cur]!
        let next = n[0] != prev ? n[0] : (n.count > 1 ? n[1] : n[0])
        prev = cur; cur = next
    }
    if loop.count > 8 { loops.append(loop) }
}
// simplify (Ramer-Douglas-Peucker) and print
func rdp(_ p: [(Double, Double)], _ eps: Double) -> [(Double, Double)] {
    if p.count < 3 { return p }
    let (x0, y0) = p[0], (x1, y1) = p[p.count - 1]
    let L = max(((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)).squareRoot(), 1e-9)
    var dm = 0.0, k = 0
    for i in 1..<(p.count - 1) { let d = abs((y1 - y0) * p[i].0 - (x1 - x0) * p[i].1 + x1 * y0 - y1 * x0) / L; if d > dm { dm = d; k = i } }
    if dm <= eps { return [p[0], p[p.count - 1]] }
    return Array(rdp(Array(p[0...k]), eps).dropLast()) + rdp(Array(p[k...]), eps)
}
var out = ""
var count = 0
for l in loops {
    let half = l.count / 2
    let s1 = rdp(Array(l[0...half]), 0.12), s2 = rdp(Array(l[half...]) + [l[0]], 0.12)
    let q = Array(s1.dropLast()) + Array(s2.dropLast())
    count += q.count
    out += "M" + q.map { String(format: "%.1f %.1f", $0.0, $0.1) }.joined(separator: "L") + "Z"
}
try! out.write(toFile: a[4], atomically: true, encoding: .utf8)
print(loops.count, "loops,", count, "points,", out.count, "chars")
