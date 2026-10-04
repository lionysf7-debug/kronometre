// Kronometre uygulama simgesini (1024×1024 PNG) kodla çizer. make-icon.sh bunu .icns'e çevirir.
// Kadran, geçen süreyi renk geçişli bir yayla gösterir; altında menü çubuğundaki gibi dijital süre.
// Koordinatlar CoreGraphics'in y yukarı düzenindedir.
import AppKit

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)   // Apple simge şablonundaki kare
let radius: CGFloat = 185
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func mix(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
    let x = a.components!, y = b.components!
    return CGColor(srgbRed: x[0] + (y[0] - x[0]) * t, green: x[1] + (y[1] - x[1]) * t,
                   blue: x[2] + (y[2] - x[2]) * t, alpha: 1)
}

guard let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("bağlam yok") }
ctx.setLineCap(.round)
let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

// Zemin: gece mavisinden mora
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.35))
ctx.addPath(tilePath)
ctx.setFillColor(color(0x12132e))
ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let bg = CGGradient(colorsSpace: space, colors: [color(0x2a2470), color(0x0b0b22)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 300, y: tile.maxY), end: CGPoint(x: 700, y: tile.minY),
                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

let center = CGPoint(x: 512, y: 488)
let glow = CGGradient(colorsSpace: space, colors: [color(0x6a5cff, 0.35), color(0x6a5cff, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: 360, options: [])

// Taç ve yan düğme
ctx.setFillColor(color(0xe8ecff))
ctx.addPath(CGPath(roundedRect: CGRect(x: 482, y: 760, width: 60, height: 70), cornerWidth: 12, cornerHeight: 12, transform: nil))
ctx.fillPath()
ctx.addPath(CGPath(roundedRect: CGRect(x: 432, y: 815, width: 160, height: 46), cornerWidth: 23, cornerHeight: 23, transform: nil))
ctx.fillPath()
ctx.saveGState()
ctx.translateBy(x: center.x, y: center.y)
ctx.rotate(by: -.pi / 4)
ctx.addPath(CGPath(roundedRect: CGRect(x: -28, y: 280, width: 56, height: 62), cornerWidth: 12, cornerHeight: 12, transform: nil))
ctx.fillPath()
ctx.restoreGState()

// Kasa
ctx.setStrokeColor(color(0xe8ecff))
ctx.setLineWidth(30)
ctx.strokeEllipse(in: CGRect(x: center.x - 280, y: center.y - 280, width: 560, height: 560))
ctx.setFillColor(color(0x0c0c20, 0.9))
ctx.fillEllipse(in: CGRect(x: center.x - 262, y: center.y - 262, width: 524, height: 524))

// Çentikler
for i in 0..<60 {
    let a = CGFloat(i) / 60 * .pi * 2
    let long = i % 5 == 0
    let r1: CGFloat = long ? 168 : 182, r2: CGFloat = 200
    ctx.setStrokeColor(color(0xffffff, long ? 0.75 : 0.28))
    ctx.setLineWidth(long ? 9 : 5)
    ctx.move(to: CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1))
    ctx.addLine(to: CGPoint(x: center.x + cos(a) * r2, y: center.y + sin(a) * r2))
    ctx.strokePath()
}

// Geçen süre yayı: saat 12'den saat yönünde, camgöbeği → mor → pembe
let arcR: CGFloat = 228
let start: CGFloat = .pi / 2
let sweep: CGFloat = 250 * .pi / 180
ctx.setStrokeColor(color(0xffffff, 0.08))
ctx.setLineWidth(34)
ctx.strokeEllipse(in: CGRect(x: center.x - arcR, y: center.y - arcR, width: arcR * 2, height: arcR * 2))
let stops = [color(0x38d6ff), color(0x7a5cff), color(0xff3fb4)]
let steps = 160
ctx.setLineCap(.butt)
ctx.setLineWidth(34)
for i in 0..<steps {
    let t0 = CGFloat(i) / CGFloat(steps), t1 = CGFloat(i + 1) / CGFloat(steps)
    let seg = t0 < 0.5 ? mix(stops[0], stops[1], t0 * 2) : mix(stops[1], stops[2], (t0 - 0.5) * 2)
    ctx.setStrokeColor(seg)
    ctx.addArc(center: center, radius: arcR, startAngle: start - sweep * t0, endAngle: start - sweep * t1 - 0.004, clockwise: true)
    ctx.strokePath()
}
ctx.setLineCap(.round)
ctx.setFillColor(stops[0])
ctx.fillEllipse(in: CGRect(x: center.x - 17, y: center.y + arcR - 17, width: 34, height: 34))
let endAngle = start - sweep
let tip = CGPoint(x: center.x + cos(endAngle) * arcR, y: center.y + sin(endAngle) * arcR)
ctx.setShadow(offset: .zero, blur: 30, color: color(0xff3fb4, 0.9))
ctx.setFillColor(color(0xff3fb4))
ctx.fillEllipse(in: CGRect(x: tip.x - 24, y: tip.y - 24, width: 48, height: 48))
ctx.setShadow(offset: .zero, blur: 0, color: nil)
ctx.setFillColor(color(0xffffff))
ctx.fillEllipse(in: CGRect(x: tip.x - 10, y: tip.y - 10, width: 20, height: 20))

// Dijital süre (menü çubuğundaki gösterim)
let pill = CGRect(x: center.x - 130, y: center.y - 150, width: 260, height: 84)
ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 42, cornerHeight: 42, transform: nil))
ctx.setFillColor(color(0x1c1b44))
ctx.fillPath()
ctx.addPath(CGPath(roundedRect: pill, cornerWidth: 42, cornerHeight: 42, transform: nil))
ctx.setStrokeColor(color(0x38d6ff, 0.6))
ctx.setLineWidth(4)
ctx.strokePath()
let digits = NSAttributedString(string: "00:42", attributes: [
    .font: NSFont.monospacedDigitSystemFont(ofSize: 60, weight: .bold),
    .foregroundColor: NSColor(srgbRed: 0.75, green: 0.93, blue: 1, alpha: 1),
])
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
let size = digits.size()
digits.draw(at: CGPoint(x: pill.midX - size.width / 2, y: pill.midY - size.height / 2))
NSGraphicsContext.restoreGraphicsState()

// Akrep: merkezden yayın ucuna
ctx.setStrokeColor(color(0xffffff))
ctx.setLineWidth(16)
ctx.move(to: center)
ctx.addLine(to: CGPoint(x: center.x + cos(endAngle) * 175, y: center.y + sin(endAngle) * 175))
ctx.strokePath()
ctx.setFillColor(color(0xffffff))
ctx.fillEllipse(in: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52))
ctx.setFillColor(color(0xff3fb4))
ctx.fillEllipse(in: CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22))

// Parlama ve ince kenar
let gloss = CGGradient(colorsSpace: space, colors: [color(0xffffff, 0.10), color(0xffffff, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gloss, start: CGPoint(x: 512, y: tile.maxY), end: CGPoint(x: 512, y: tile.midY + 120), options: [])
ctx.restoreGState()
ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), cornerWidth: radius - 1.5, cornerHeight: radius - 1.5, transform: nil))
ctx.setStrokeColor(color(0xffffff, 0.12))
ctx.setLineWidth(3)
ctx.strokePath()

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png")
guard let image = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("PNG yok") }
try data.write(to: out)
print("✓ \(out.path)")
