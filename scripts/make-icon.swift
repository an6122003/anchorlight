import AppKit

// Renders the Anchorlight app icon: a warm light kept burning above a closed
// laptop — lid shut, still awake.
let size: CGFloat = 1024
let inset: CGFloat = 100
let plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
cg.translateBy(x: 0, y: size)
cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let squircle = NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.225, yRadius: plate.width * 0.225)
NSGraphicsContext.saveGraphicsState()
squircle.addClip()
NSGradient(colors: [color(0x4A3FA8), color(0x22246B), color(0x0D1238)],
           atLocations: [0, 0.5, 1], colorSpace: .sRGB)?.draw(in: plate, angle: -62)

// A few stars.
for (x, y, r, a) in [(250.0, 230.0, 7.0, 0.9), (760.0, 250.0, 5.0, 0.7), (690.0, 180.0, 4.0, 0.6),
                     (330.0, 330.0, 4.0, 0.55), (820.0, 400.0, 6.0, 0.8), (190.0, 440.0, 4.0, 0.5)] {
    color(0xFFFFFF, a).setFill()
    NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill()
}

// The anchor light: a warm glow with a bright core.
let lightCenter = CGPoint(x: 512, y: 430)
// Drawn over the whole plate rather than clipped to a circle, so the glow
// falls off smoothly instead of ending on a visible edge.
NSGradient(colors: [color(0xFFC75A, 0.70), color(0xFFA048, 0.32), color(0xFF9A3C, 0.08), color(0xFF9A3C, 0.0)],
           atLocations: [0, 0.16, 0.42, 1], colorSpace: .sRGB)?
    .draw(in: plate, relativeCenterPosition: NSPoint(x: 0, y: -0.2))
NSGradient(colors: [color(0xFFFBEA), color(0xFFE08A), color(0xFFB648)],
           atLocations: [0, 0.55, 1], colorSpace: .sRGB)?
    .draw(in: NSBezierPath(ovalIn: CGRect(x: lightCenter.x - 78, y: lightCenter.y - 78, width: 156, height: 156)),
          relativeCenterPosition: NSPoint(x: -0.2, y: 0.25))

// The closed laptop, lit from above: lid over a slightly darker base.
let lid = CGRect(x: 236, y: 664, width: 552, height: 40)
let shadow = NSShadow()
shadow.shadowColor = color(0x000000, 0.45)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -14)
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSGradient(colors: [color(0xF3F5FB), color(0xC3CADB)])?.draw(in: NSBezierPath(roundedRect: lid, xRadius: 20, yRadius: 20), angle: -90)
NSGraphicsContext.restoreGraphicsState()
color(0xFFC75A, 0.85).setFill()
NSBezierPath(roundedRect: CGRect(x: lid.minX + 60, y: lid.minY + 3, width: lid.width - 120, height: 5), xRadius: 2.5, yRadius: 2.5).fill()
NSGradient(colors: [color(0xA9B1C6), color(0x7E879E)])?
    .draw(in: NSBezierPath(roundedRect: CGRect(x: lid.minX + 6, y: lid.maxY - 6, width: lid.width - 12, height: 18),
                           xRadius: 9, yRadius: 9), angle: -90)

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
