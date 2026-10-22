// Renders the 1024×1024 Turnout app icon: a railway junction seen from above, on a macOS-style
// rounded square. One track comes up the middle and splits; the left branch is soft white, the
// right branch is lit amber (the route the switch is set to). Usage: swift make-icon.swift <out.png>
import AppKit
import CoreGraphics

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// Apple icon grid: 824pt body centred in 1024, ~185pt corner radius.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow + gradient body.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(squircle)
ctx.setFillColor(rgb(0x14213D))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
let bg = CGGradient(colorsSpace: space, colors: [rgb(0x1C7C7D), rgb(0x173F5F), rgb(0x111A33)] as CFArray,
                    locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 180, y: 924), end: CGPoint(x: 844, y: 100), options: [])

// Track geometry: a stem up the centre, then mirrored branches.
let gauge: CGFloat = 120   // centre-to-centre rail spacing
let rail: CGFloat = 40     // rail thickness
let stemTop: CGFloat = 360

struct Curve { let p0, p1, p2, p3: CGPoint }
func branch(_ side: CGFloat) -> Curve {
    Curve(p0: CGPoint(x: 512, y: stemTop), p1: CGPoint(x: 512, y: 560),
          p2: CGPoint(x: 512 + side * 140, y: 700), p3: CGPoint(x: 512 + side * 300, y: 960))
}
let left = branch(-1), right = branch(1)

func point(_ c: Curve, _ t: CGFloat) -> (CGPoint, CGVector) {
    let u = 1 - t
    let x = u*u*u*c.p0.x + 3*u*u*t*c.p1.x + 3*u*t*t*c.p2.x + t*t*t*c.p3.x
    let y = u*u*u*c.p0.y + 3*u*u*t*c.p1.y + 3*u*t*t*c.p2.y + t*t*t*c.p3.y
    let dx = 3*u*u*(c.p1.x-c.p0.x) + 6*u*t*(c.p2.x-c.p1.x) + 3*t*t*(c.p3.x-c.p2.x)
    let dy = 3*u*u*(c.p1.y-c.p0.y) + 6*u*t*(c.p2.y-c.p1.y) + 3*t*t*(c.p3.y-c.p2.y)
    let len = (dx*dx + dy*dy).squareRoot()
    return (CGPoint(x: x, y: y), CGVector(dx: dx/len, dy: dy/len))
}

func trackPath(_ c: Curve) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 512, y: 40))
    p.addLine(to: c.p0)
    p.addCurve(to: c.p3, control1: c.p1, control2: c.p2)
    return p
}

// Sleepers (ties), drawn under the rails; skipped where the branches still overlap.
func tie(at c: CGPoint, dir: CGVector, color: CGColor) {
    let n = CGVector(dx: -dir.dy, dy: dir.dx)
    let half = gauge / 2 + 52, w: CGFloat = 15
    let pts = [CGPoint(x: c.x + n.dx*half + dir.dx*w, y: c.y + n.dy*half + dir.dy*w),
               CGPoint(x: c.x - n.dx*half + dir.dx*w, y: c.y - n.dy*half + dir.dy*w),
               CGPoint(x: c.x - n.dx*half - dir.dx*w, y: c.y - n.dy*half - dir.dy*w),
               CGPoint(x: c.x + n.dx*half - dir.dx*w, y: c.y + n.dy*half - dir.dy*w)]
    ctx.addLines(between: pts)
    ctx.closePath()
    ctx.setFillColor(color)
    ctx.fillPath()
}
var y: CGFloat = 70
while y < stemTop + 40 { tie(at: CGPoint(x: 512, y: y), dir: CGVector(dx: 0, dy: 1), color: rgb(0xFFFFFF, 0.18)); y += 82 }
for t in stride(from: 0.62, through: 1.0, by: 0.125) {
    let (lc, ld) = point(left, CGFloat(t)); tie(at: lc, dir: ld, color: rgb(0xFFFFFF, 0.14))
    let (rc, rd) = point(right, CGFloat(t)); tie(at: rc, dir: rd, color: rgb(0xFFB703, 0.22))
}

// Each track is a wide stroke with its middle punched out, in its own layer so the branch
// doesn't erase the main line's rails where they overlap.
func drawTrack(_ path: CGPath, color: CGColor, glow: CGColor?) {
    let layer = CGLayer(ctx, size: CGSize(width: size, height: size), auxiliaryInfo: nil)!
    let lc = layer.context!
    lc.setLineCap(.butt)
    lc.addPath(path)
    lc.setLineWidth(gauge + rail)
    lc.setStrokeColor(color)
    lc.strokePath()
    lc.setBlendMode(.clear)
    lc.addPath(path)
    lc.setLineWidth(gauge - rail)
    lc.strokePath()
    ctx.saveGState()
    if let glow { ctx.setShadow(offset: .zero, blur: 26, color: glow) }
    ctx.draw(layer, at: .zero)
    ctx.restoreGState()
}
drawTrack(trackPath(left), color: rgb(0xE8EEF5, 0.78), glow: nil)
drawTrack(trackPath(right), color: rgb(0xFFB703), glow: rgb(0xFFB703, 0.55))

// Faint top highlight and edge so the body reads on dark Docks.
let shine = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.10), rgb(0xFFFFFF, 0)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(shine, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 600), options: [])
ctx.restoreGState()

ctx.addPath(squircle)
ctx.setStrokeColor(rgb(0xFFFFFF, 0.12))
ctx.setLineWidth(3)
ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
