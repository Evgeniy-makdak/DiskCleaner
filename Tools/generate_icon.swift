// Генерирует иконку приложения (щётка/диск в стиле SF Symbols) в PNG.
// Запуск: swift Tools/generate_icon.swift <output-dir>
// Зависимости: только AppKit (macOS).

import AppKit

let symbolName = "externaldrive.fill.badge.checkmark"
let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let sizes: [(name: String, points: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.95, alpha: 1),
        NSColor(calibratedRed: 0.45, green: 0.28, blue: 0.92, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -90)

    if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Disk Cleaner") {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .medium)
        if let configured = symbol.withSymbolConfiguration(config) {
            let symbolSize = configured.size
            let origin = NSPoint(x: (size - symbolSize.width) / 2, y: (size - symbolSize.height) / 2)
            configured.draw(in: NSRect(origin: origin, size: symbolSize))
        }
    }
    return image
}

func writePNG(_ image: NSImage, to url: URL, pixelSize: CGFloat) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(pixelSize),
        pixelsHigh: Int(pixelSize),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: pixelSize, height: pixelSize)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    if let data = bitmap.representation(using: .png, properties: [:]) {
        try? data.write(to: url)
    }
}

let fm = FileManager.default
for s in sizes {
    let icon = makeIcon(size: s.points)
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(s.name).png")
    writePNG(icon, to: url, pixelSize: s.points)
    print("Wrote \(url.path)")
}
print("Done: \(sizes.count) icons")