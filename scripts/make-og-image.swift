// 生成官网 OG 分享图（1200×630）：米色底 + 陶土橙星芒 + 衬线字标 + 港湾胶囊
// 用法: swift scripts/make-og-image.swift [输出路径]

import AppKit

let size = NSSize(width: 1200, height: 630)
let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "website/og-image.png"

let cream = NSColor(calibratedWhite: 0.97, alpha: 1) // #FAF9F5 近似
let ink = NSColor(calibratedWhite: 0.10, alpha: 1)
let inkSoft = NSColor(calibratedWhite: 0.33, alpha: 1)
let coral = NSColor(srgbRed: 0.85, green: 0.47, blue: 0.34, alpha: 1) // #D97757
let teal = NSColor(srgbRed: 0.06, green: 0.46, blue: 0.43, alpha: 1)  // #0F766E

let image = NSImage(size: size)
image.lockFocusFlipped(false)

guard let context = NSGraphicsContext.current?.cgContext else {
    FileHandle.standardError.write("no graphics context\n".data(using: .utf8)!)
    exit(1)
}

// 底色
cream.setFill()
context.fill(CGRect(origin: .zero, size: NSSize(width: 1200, height: 630)))

// 底部橙色柔光
let glow = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(srgbRed: 0.85, green: 0.47, blue: 0.34, alpha: 0.14),
        CGColor(srgbRed: 0.85, green: 0.47, blue: 0.34, alpha: 0),
    ] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: 600, y: -60),
    startRadius: 0,
    endCenter: CGPoint(x: 600, y: -60),
    endRadius: 620,
    options: [.drawsAfterEndLocation]
)

func drawCentered(_ text: String, font: NSFont, color: NSColor, y: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let bounds = attributed.boundingRect(
        with: NSSize(width: 1100, height: 200),
        options: [.usesLineFragmentOrigin]
    )
    attributed.draw(at: NSPoint(x: (1200 - bounds.width) / 2, y: y))
}

// 星芒（8 轴 = 4 条穿过圆心的线）
let starCenter = CGPoint(x: 600, y: 492)
let radius: CGFloat = 30
context.setStrokeColor(coral.cgColor)
context.setLineWidth(9)
context.setLineCap(.round)
for angle in stride(from: 0.0, to: 180.0, by: 45.0) {
    let rad = angle * .pi / 180
    context.move(to: starCenter)
    context.addLine(to: CGPoint(
        x: starCenter.x + cos(rad) * radius,
        y: starCenter.y + sin(rad) * radius
    ))
    context.strokePath()
}

// 字标与标语
drawCentered(
    "MenuHarbor",
    font: NSFont(name: "Georgia-Bold", size: 116) ?? NSFont.boldSystemFont(ofSize: 116),
    color: ink,
    y: 300
)
drawCentered(
    "刘海挡不住的 macOS 菜单栏港湾",
    font: NSFont.systemFont(ofSize: 42, weight: .medium),
    color: inkSoft,
    y: 228
)

// 港湾胶囊
let pill = CGRect(x: 420, y: 108, width: 360, height: 58)
teal.setFill()
context.addPath(CGPath(
    roundedRect: pill, cornerWidth: 29, cornerHeight: 29, transform: nil
))
context.fillPath()
drawCentered(
    "港湾 · 溢出图标自动停靠",
    font: NSFont.systemFont(ofSize: 26, weight: .semibold),
    color: NSColor(calibratedWhite: 0.98, alpha: 1),
    y: 124
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("png encode failed\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: output))
print("wrote \(output)")
