// 生成 MenuHarbor 应用图标：港湾托盘（下半填充的圆角矩形）+ 港湾青色底。
// 用法：swift scripts/make-icon.swift && iconutil -c icns scripts/icon.iconset -o Resources/AppIcon.icns
import AppKit

let canvas: CGFloat = 1024
let image = NSImage(size: NSSize(width: canvas, height: canvas))
image.lockFocus()

let backgroundRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 184, yRadius: 184)
NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.64, blue: 0.61, alpha: 1),
    NSColor(calibratedRed: 0.02, green: 0.40, blue: 0.44, alpha: 1),
])?.draw(in: backgroundPath, angle: -90)
backgroundPath.addClip()

// 托盘轮廓：圆角矩形描边 + 下半部分填充，对应菜单栏按钮的 SF Symbol 隐喻。
let glyphRect = CGRect(x: 272, y: 316, width: 480, height: 392)
let cornerRadius: CGFloat = 96
let strokePath = NSBezierPath(roundedRect: glyphRect, xRadius: cornerRadius, yRadius: cornerRadius)
strokePath.lineWidth = 56
NSColor.white.setStroke()
strokePath.stroke()

NSBezierPath(roundedRect: glyphRect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
NSColor.white.setFill()
NSBezierPath(rect: CGRect(
    x: glyphRect.minX,
    y: glyphRect.minY,
    width: glyphRect.width,
    height: glyphRect.height * 0.5
)).fill()

image.unlockFocus()

func pngData(_ size: Int) -> Data? {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let iconset = "scripts/icon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// Apple iconset 命名约定：逻辑尺寸 + @2x 像素尺寸。
let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for entry in entries {
    guard let data = pngData(entry.pixels) else {
        fatalError("Failed to render \(entry.name)")
    }
    try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(entry.name)"))
    print("wrote \(iconset)/\(entry.name) (\(entry.pixels)px)")
}
