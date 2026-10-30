import AppKit
import CoreText

// outline.swift: reads lines "id|font|text|tracking" from stdin, prints "id|x0 y0 x1 y1|path" with the
// text outlined at 1000 units per em, y down, baseline at 0. Kerning stays on; tracking is in em.
// font: system:<weight>:<width> | serif:<weight> | mono:<weight> | rounded:<weight>
//       | name:<PostScript name> | file:<path>[:tag=value,tag=value]

let size: CGFloat = 1000

func weight(_ s: String) -> NSFont.Weight {
    ["ultralight": .ultraLight, "thin": .thin, "light": .light, "regular": .regular, "medium": .medium,
     "semibold": .semibold, "bold": .bold, "heavy": .heavy, "black": .black][s] ?? .regular
}

func width(_ s: String) -> NSFont.Width {
    ["compressed": .compressed, "condensed": .condensed, "standard": .standard, "expanded": .expanded][s] ?? .standard
}

func font(_ spec: String) -> CTFont {
    let p = spec.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
    switch p[0] {
    case "system":
        return NSFont.systemFont(ofSize: size, weight: weight(p[1]), width: width(p.count > 2 ? p[2] : "standard"))
    case "serif", "mono", "rounded":
        let design: NSFontDescriptor.SystemDesign = p[0] == "serif" ? .serif : p[0] == "mono" ? .monospaced : .rounded
        let base = NSFont.systemFont(ofSize: size, weight: weight(p[1]))
        return NSFont(descriptor: base.fontDescriptor.withDesign(design)!, size: size)!
    case "name":
        return CTFontCreateWithName(p[1] as CFString, size, nil)
    default:
        let url = URL(fileURLWithPath: p[1]) as CFURL
        let descs = CTFontManagerCreateFontDescriptorsFromURL(url) as! [CTFontDescriptor]
        var desc = descs[0]
        if p.count > 2, !p[2].isEmpty {
            var axes: [NSNumber: NSNumber] = [:]
            for kv in p[2].split(separator: ",") {
                let t = kv.split(separator: "=")
                let tag = t[0].unicodeScalars.reduce(0) { ($0 << 8) | Int($1.value) }
                axes[NSNumber(value: tag)] = NSNumber(value: Double(t[1])!)
            }
            desc = CTFontDescriptorCreateCopyWithAttributes(desc, [kCTFontVariationAttribute: axes] as CFDictionary)
        }
        return CTFontCreateWithFontDescriptor(desc, size, nil)
    }
}

func svg(_ path: CGPath) -> String {
    var d = ""
    let n = { (v: CGFloat) in String(format: "%.1f", v) }
    path.applyWithBlock { e in
        let pts = e.pointee.points
        switch e.pointee.type {
        case .moveToPoint: d += "M\(n(pts[0].x)) \(n(-pts[0].y))"
        case .addLineToPoint: d += "L\(n(pts[0].x)) \(n(-pts[0].y))"
        case .addQuadCurveToPoint: d += "Q\(n(pts[0].x)) \(n(-pts[0].y)) \(n(pts[1].x)) \(n(-pts[1].y))"
        case .addCurveToPoint: d += "C\(n(pts[0].x)) \(n(-pts[0].y)) \(n(pts[1].x)) \(n(-pts[1].y)) \(n(pts[2].x)) \(n(-pts[2].y))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

while let line = readLine() {
    let p = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    guard p.count == 4 else { continue }
    let ct = font(p[1])
    let attrs: [NSAttributedString.Key: Any] = [.init(kCTFontAttributeName as String): ct, .kern: Double(p[3])! * size]
    let ctLine = CTLineCreateWithAttributedString(NSAttributedString(string: p[2], attributes: attrs))
    let out = CGMutablePath()
    for run in CTLineGetGlyphRuns(ctLine) as! [CTRun] {
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count), pos = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &pos)
        for i in 0..<count {
            if let g = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                out.addPath(g, transform: CGAffineTransform(translationX: pos[i].x, y: pos[i].y))
            }
        }
    }
    let b = out.boundingBoxOfPath
    print("\(p[0])|\(b.minX) \(-b.maxY) \(b.maxX) \(-b.minY)|\(svg(out))")
}
