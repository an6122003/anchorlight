import AppKit
import CoreImage

// Renders the Anchorlight README artwork into docs/images, drawn natively with
// real SF Symbols and the system font.
//
//   swiftc -O -o /tmp/art scripts/make-readme-art.swift && /tmp/art docs/images Resources/AppIcon.icns

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images"
let iconPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Resources/AppIcon.icns"
try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

// MARK: - Basics

func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: alpha)
}

enum Brand {
    static let mint = hex(0x3FE0C5)
    static let teal = hex(0x2BB5A8)
    static let indigo = hex(0x4B3BB8)
    static let selection = hex(0x2F6BF0)
}

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: descriptor, size: size) ?? base
}

/// A 2× bitmap with a flipped (y-down) drawing context.
final class Canvas {
    let size: CGSize
    let rep: NSBitmapImageRep

    init(_ width: CGFloat, _ height: CGFloat, scale: CGFloat = 2) {
        size = CGSize(width: width, height: height)
        rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: width, height: height)
    }

    func draw(_ body: (CGRect) -> Void) {
        NSGraphicsContext.saveGraphicsState()
        let base = NSGraphicsContext(bitmapImageRep: rep)!
        let cg = base.cgContext
        cg.translateBy(x: 0, y: size.height)
        cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        body(CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
    }

    func save(_ name: String) {
        let path = (outputDirectory as NSString).appendingPathComponent(name)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        print("wrote \(path)")
    }
}

func drawImage(_ image: NSImage, in rect: CGRect, alpha: CGFloat = 1) {
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: nil)
}

@discardableResult
func text(_ string: String, at point: CGPoint, font: NSFont, color: NSColor,
          kern: CGFloat = 0, width: CGFloat? = nil, alignment: NSTextAlignment = .left) -> CGSize {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributed = NSAttributedString(string: string, attributes: [
        .font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: paragraph,
    ])
    let measured = attributed.size()
    if let width {
        attributed.draw(in: CGRect(x: point.x, y: point.y, width: width, height: measured.height + 4))
    } else {
        attributed.draw(at: point)
    }
    return measured
}

func textSize(_ string: String, font: NSFont) -> CGSize {
    NSAttributedString(string: string, attributes: [.font: font]).size()
}

func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .white) -> NSImage? {
    let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
}

func drawSymbol(_ name: String, center: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular,
                color: NSColor = .white, alpha: CGFloat = 1) {
    guard let image = symbol(name, size: size, weight: weight, color: color) else { return }
    let s = image.size
    drawImage(image, in: CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height), alpha: alpha)
}

func shadowed(_ color: NSColor, blur: CGFloat, offset: CGFloat, _ body: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -offset)
    shadow.set()
    body()
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Wallpaper

/// A dark aurora, rendered once per image so the glass panels can blur it.
func wallpaper(_ size: CGSize, scale: CGFloat = 2, variant: Int = 0) -> NSImage {
    let width = Int(size.width * scale), height = Int(size.height * scale)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                       space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let w = CGFloat(width), h = CGFloat(height)

    let base = CGGradient(colorsSpace: space, colors: [hex(0x0A0F2C).cgColor, hex(0x170F3D).cgColor, hex(0x0B1A33).cgColor] as CFArray,
                          locations: [0, 0.55, 1])!
    cg.drawLinearGradient(base, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])

    let blobs: [(CGFloat, CGFloat, CGFloat, UInt32, CGFloat)] = variant == 0
        ? [(0.82, 0.18, 0.55, 0x22D3B6, 0.55), (0.18, 0.35, 0.60, 0x6D4CFF, 0.50),
           (0.55, 0.95, 0.45, 0x3A7BFF, 0.40), (0.95, 0.85, 0.40, 0xFF5D9E, 0.22)]
        : [(0.25, 0.20, 0.55, 0x22D3B6, 0.45), (0.80, 0.40, 0.65, 0x6D4CFF, 0.50),
           (0.45, 0.90, 0.50, 0x3A7BFF, 0.35), (0.05, 0.85, 0.40, 0xFF7A59, 0.18)]
    for (fx, fy, fr, color, alpha) in blobs {
        let center = CGPoint(x: w * fx, y: h * (1 - fy))
        let radius = max(w, h) * fr
        let gradient = CGGradient(colorsSpace: space, colors: [hex(color, alpha).cgColor, hex(color, 0).cgColor] as CFArray,
                                  locations: [0, 1])!
        cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    return NSImage(cgImage: cg.makeImage()!, size: size)
}

func blurred(_ image: NSImage, radius: CGFloat) -> NSImage {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
    let input = CIImage(cgImage: cgImage)
    let output = input.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: input.extent)
    let context = CIContext()
    guard let result = context.createCGImage(output, from: input.extent) else { return image }
    return NSImage(cgImage: result, size: image.size)
}

/// Frosted glass: the blurred backdrop clipped to a shape, then tinted.
func glass(_ path: NSBezierPath, backdrop: NSImage, canvas: CGRect, tint: NSColor, border: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    drawImage(backdrop, in: canvas)
    tint.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    border.setStroke()
    path.lineWidth = 1
    path.stroke()
}

func pill(_ symbolName: String, _ label: String, at point: CGPoint, tint: NSColor) {
    let font = rounded(13, .semibold)
    let size = textSize(label, font: font)
    let rect = CGRect(x: point.x, y: point.y, width: size.width + 40, height: 26)
    tint.withAlphaComponent(0.20).setFill()
    let path = NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13)
    path.fill()
    tint.withAlphaComponent(0.55).setStroke()
    path.lineWidth = 1
    path.stroke()
    drawSymbol(symbolName, center: CGPoint(x: rect.minX + 15, y: rect.midY), size: 11, weight: .bold, color: tint)
    text(label, at: CGPoint(x: rect.minX + 27, y: rect.midY - size.height / 2), font: font, color: .white)
}

// MARK: - Anchorlight

let accent = hex(0x0A84FF)      // the system accent the app tints its icon with
let amber = hex(0xFFC75A)

/// A night sky with a warm glow low on the horizon.
func nightWallpaper(_ size: CGSize, scale: CGFloat = 2) -> NSImage {
    let width = Int(size.width * scale), height = Int(size.height * scale)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let cg = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                       space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let w = CGFloat(width), h = CGFloat(height)
    let base = CGGradient(colorsSpace: space, colors: [hex(0x080B24).cgColor, hex(0x141A4A).cgColor, hex(0x1E1446).cgColor] as CFArray,
                          locations: [0, 0.6, 1])!
    // Extended both ways so it covers the whole canvas; a gradient that stops
    // short leaves the rest transparent.
    cg.drawLinearGradient(base, start: CGPoint(x: 0, y: h), end: CGPoint(x: w * 0.4, y: 0),
                          options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    for (fx, fy, fr, color, alpha) in [(0.80, 0.86, 0.55, UInt32(0xFF9A3C), CGFloat(0.42)), (0.18, 0.20, 0.55, 0x5A48D8, 0.45),
                                       (0.55, 0.55, 0.45, 0x2D5BD6, 0.22)] {
        let center = CGPoint(x: w * fx, y: h * (1 - fy))
        let gradient = CGGradient(colorsSpace: space, colors: [hex(color, alpha).cgColor, hex(color, 0).cgColor] as CFArray, locations: [0, 1])!
        cg.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: max(w, h) * fr, options: [])
    }
    // Stars, placed deterministically so every render matches.
    var seed: UInt64 = 0x5EED
    func next() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(1 << 31) }
    for _ in 0..<70 {
        let x = next() * w, y = h - next() * h * 0.7, r = (0.6 + next() * 1.4) * scale, a = 0.25 + next() * 0.6
        cg.setFillColor(hex(0xFFFFFF, a).cgColor)
        cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
    return NSImage(cgImage: cg.makeImage()!, size: size)
}

/// The right-hand end of the menu bar, with Anchorlight's icon showing AWAKE.
func drawBar(width: CGFloat, height: CGFloat, highlight: Bool = false, notchAt: CGFloat? = nil) -> CGRect {
    NSGradient(colors: [hex(0x000000, 0.36), hex(0x000000, 0)])?
        .draw(in: CGRect(x: 0, y: 0, width: width, height: height * 1.6), angle: 90)
    let midY = height / 2
    var x = width - 14
    let clockFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    let clock = "Fri 23 Oct  01:40"
    x -= textSize(clock, font: clockFont).width
    text(clock, at: CGPoint(x: x, y: midY - textSize(clock, font: clockFont).height / 2), font: clockFont, color: .white)
    x -= 16
    for name in ["switch.2", "magnifyingglass", "battery.75percent", "wifi"] {
        drawSymbol(name, center: CGPoint(x: x - 11, y: midY), size: 14.5, weight: .medium)
        x -= 34
    }
    let badge = CGRect(x: x - 22, y: midY - 8.5, width: 22, height: 17)
    hex(0xFFFFFF, 0.92).setFill()
    NSBezierPath(roundedRect: badge, xRadius: 4.5, yRadius: 4.5).fill()
    let letterFont = NSFont.systemFont(ofSize: 11, weight: .bold)
    text("A", at: CGPoint(x: badge.midX - textSize("A", font: letterFont).width / 2, y: badge.midY - textSize("A", font: letterFont).height / 2),
         font: letterFont, color: hex(0x15151A))
    x -= 38

    // Anchorlight: the tinted cup and its AWAKE label.
    let labelFont = NSFont.systemFont(ofSize: 11, weight: .bold)
    let labelWidth = textSize(" AWAKE", font: labelFont).width
    let item = CGRect(x: x - 22 - labelWidth, y: 3, width: 26 + labelWidth, height: height - 6)
    if highlight {
        hex(0xFFFFFF, 0.22).setFill()
        NSBezierPath(roundedRect: item.insetBy(dx: -5, dy: 0), xRadius: 6, yRadius: 6).fill()
    }
    drawSymbol("cup.and.saucer.fill", center: CGPoint(x: item.minX + 10, y: midY), size: 14.5, weight: .medium, color: accent)
    text(" AWAKE", at: CGPoint(x: item.minX + 20, y: midY - textSize(" AWAKE", font: labelFont).height / 2), font: labelFont,
         color: accent, kern: 0.4)

    if let notchAt {
        hex(0x020204).setFill()
        NSBezierPath(roundedRect: CGRect(x: notchAt, y: -10, width: 185 * (width / 1710), height: height + 10),
                     xRadius: 9, yRadius: 9).fill()
    }
    return item
}

func drawHUD(_ rect: CGRect, symbolName: String, title: String, detail: String, tint: NSColor, backdrop: NSImage, canvas: CGRect) {
    let shape = NSBezierPath(roundedRect: rect, xRadius: 24, yRadius: 24)
    shadowed(hex(0x000000, 0.5), blur: 40, offset: 16) { hex(0x000000, 0.01).setFill(); shape.fill() }
    glass(shape, backdrop: backdrop, canvas: canvas, tint: hex(0x1A1C2E, 0.62), border: hex(0xFFFFFF, 0.14))
    drawSymbol(symbolName, center: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.36), size: rect.width * 0.27, color: tint)
    let titleFont = NSFont.systemFont(ofSize: rect.width * 0.071, weight: .semibold)
    let titleSize = textSize(title, font: titleFont)
    text(title, at: CGPoint(x: rect.midX - titleSize.width / 2, y: rect.minY + rect.height * 0.62), font: titleFont, color: .white)
    let detailFont = NSFont.systemFont(ofSize: rect.width * 0.05)
    let detailSize = textSize(detail, font: detailFont)
    text(detail, at: CGPoint(x: rect.midX - detailSize.width / 2, y: rect.minY + rect.height * 0.62 + titleSize.height + 6),
         font: detailFont, color: hex(0xFFFFFF, 0.6))
}

struct Copy {
    let suffix: String, top: String, bottom: String, chips: [String]
}
let copies = [
    Copy(suffix: "en", top: "Close the lid.", bottom: "Keep the light on.",
         chips: ["One shortcut", "Passwordless option", "Native Swift"]),
    Copy(suffix: "vi", top: "Gập máy lại.", bottom: "Đèn vẫn sáng.",
         chips: ["Một phím tắt", "Tuỳ chọn không cần mật khẩu", "Swift thuần"]),
    Copy(suffix: "zh", top: "合上盖子，", bottom: "灯依然亮着。",
         chips: ["一个快捷键", "可免密码", "原生 Swift"]),
]

let appIcon = NSImage(contentsOfFile: iconPath)

// MARK: Hero

for copy in copies {
    let canvas = Canvas(1280, 640)
    canvas.draw { bounds in
        let paper = nightWallpaper(bounds.size)
        drawImage(paper, in: bounds)
        let frosted = blurred(paper, radius: 22)
        _ = drawBar(width: bounds.width, height: 30, notchAt: 1280 * (763.0 / 1710))

        drawHUD(CGRect(x: 820, y: 190, width: 300, height: 260), symbolName: "cup.and.saucer.fill", title: "Staying Awake",
                detail: "Closing the lid will not sleep this Mac", tint: accent, backdrop: frosted, canvas: bounds)

        if let appIcon { drawImage(appIcon, in: CGRect(x: 64, y: 150, width: 132, height: 132)) }
        text("Anchorlight", at: CGPoint(x: 80, y: 290), font: rounded(80, .bold), color: .white, kern: -1.5)
        text(copy.top, at: CGPoint(x: 84, y: 392), font: rounded(32, .semibold), color: hex(0xFFFFFF, 0.9))
        text(copy.bottom, at: CGPoint(x: 84, y: 432), font: rounded(32, .semibold), color: amber)
        var chipX: CGFloat = 84
        for (glyph, label) in zip(["command", "key.fill", "bolt.fill"], copy.chips) {
            pill(glyph, label, at: CGPoint(x: chipX, y: 504), tint: amber)
            chipX += textSize(label, font: rounded(13, .semibold)).width + 52
        }
    }
    canvas.save("hero-\(copy.suffix).png")
}

// MARK: The menu

do {
    let canvas = Canvas(600, 320)
    canvas.draw { bounds in
        let paper = nightWallpaper(bounds.size)
        drawImage(paper, in: bounds)
        let frosted = blurred(paper, radius: 22)
        let item = drawBar(width: bounds.width, height: 30, highlight: true)

        let width: CGFloat = 340
        let rect = CGRect(x: min(item.minX - 6, bounds.width - width - 16), y: 34, width: width, height: 238)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        shadowed(hex(0x000000, 0.55), blur: 40, offset: 18) { hex(0x000000, 0.01).setFill(); shape.fill() }
        glass(shape, backdrop: frosted, canvas: bounds, tint: hex(0x1B1F2C, 0.68), border: hex(0xFFFFFF, 0.14))

        var y = rect.minY + 10
        func separator() {
            y += 5; hex(0xFFFFFF, 0.10).setFill(); CGRect(x: rect.minX + 14, y: y, width: width - 28, height: 1).fill(); y += 6
        }
        func row(_ title: String, subtitle: String? = nil, shortcut: String? = nil, chevron: Bool = false, dot: NSColor? = nil, selected: Bool = false) {
            let height: CGFloat = subtitle == nil ? 26 : 40
            if selected {
                Brand.selection.setFill()
                NSBezierPath(roundedRect: CGRect(x: rect.minX + 6, y: y, width: width - 12, height: height), xRadius: 7, yRadius: 7).fill()
            }
            var titleX = rect.minX + 30
            if let dot {
                dot.setFill()
                NSBezierPath(ovalIn: CGRect(x: rect.minX + 18, y: y + 9, width: 8, height: 8)).fill()
                titleX = rect.minX + 34
            }
            text(title, at: CGPoint(x: titleX, y: y + 4), font: .systemFont(ofSize: 13.5, weight: dot == nil ? .regular : .medium), color: .white)
            if let subtitle {
                text(subtitle, at: CGPoint(x: titleX, y: y + 21), font: .systemFont(ofSize: 11.5),
                     color: selected ? hex(0xFFFFFF, 0.82) : hex(0xFFFFFF, 0.46))
            }
            if let shortcut {
                text(shortcut, at: CGPoint(x: rect.maxX - 100, y: y + 5), font: .systemFont(ofSize: 12.5),
                     color: selected ? hex(0xFFFFFF, 0.85) : hex(0xFFFFFF, 0.42), width: 84, alignment: .right)
            }
            if chevron { drawSymbol("chevron.right", center: CGPoint(x: rect.maxX - 22, y: y + 13), size: 11, weight: .semibold, color: hex(0xFFFFFF, 0.55)) }
            y += height
        }
        row("Staying awake", subtitle: "Closing the lid will not sleep this Mac", dot: hex(0x32D74B))
        separator()
        row("Allow Sleep on Lid Close", subtitle: "Works anywhere with ⌃⌥⌘S", shortcut: "⌃⌥⌘S", selected: true)
        separator()
        row("Menu Bar Icon", chevron: true)
        row("Open at Login")
        row("Refresh", shortcut: "⌘R")
        separator()
        row("Quit Anchorlight", shortcut: "⌘Q")
    }
    canvas.save("menu.png")
}

// MARK: The confirmation panels

do {
    let canvas = Canvas(1000, 380)
    canvas.draw { bounds in
        let paper = nightWallpaper(bounds.size)
        drawImage(paper, in: bounds)
        let frosted = blurred(paper, radius: 22)
        drawHUD(CGRect(x: 170, y: 60, width: 280, height: 250), symbolName: "cup.and.saucer.fill", title: "Staying Awake",
                detail: "Closing the lid will not sleep this Mac", tint: accent, backdrop: frosted, canvas: bounds)
        drawHUD(CGRect(x: 550, y: 60, width: 280, height: 250), symbolName: "moon.zzz.fill", title: "Sleeping Normally",
                detail: "Closing the lid puts this Mac to sleep", tint: hex(0xAEB4C8), backdrop: frosted, canvas: bounds)
    }
    canvas.save("hud.png")
}

if let appIcon {
    let canvas = Canvas(256, 256, scale: 1)
    canvas.draw { bounds in drawImage(appIcon, in: bounds) }
    canvas.save("icon.png")
}
