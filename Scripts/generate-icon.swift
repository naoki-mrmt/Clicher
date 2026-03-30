#!/usr/bin/env swift

import AppKit
import CoreText
import Foundation

let masterSize = 1024
let fontPath = "font/kateru_font_ver1.0-Regular.otf"

// フォント登録
let fontURL = URL(fileURLWithPath: fontPath)
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

let families = CTFontManagerCopyAvailableFontFamilyNames() as! [String]
let kateruFamily = families.first { $0.lowercased().contains("kateru") }
print("Font family: \(kateruFamily ?? "not found")")

let fontName = kateruFamily ?? "Helvetica"

// マスター画像を CGContext で生成（ピクセル正確）
func renderIcon(pixels: Int) -> Data? {
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }

    let size = CGFloat(pixels)
    let cornerRadius = size * 0.22

    // 背景: 白の角丸
    let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
                        cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.setFillColor(CGColor.white)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // テキスト描画
    let fontSize = size * 0.18
    guard let font = NSFont(name: fontName, size: fontSize) else { return nil }

    let text = "Clicher" as NSString
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.black,
    ]
    let textSize = text.size(withAttributes: attrs)

    // NSGraphicsContext 経由で描画（CGContext 上）
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    let textPoint = NSPoint(
        x: (size - textSize.width) / 2,
        y: (size - textSize.height) / 2 - size * 0.02
    )
    text.draw(at: textPoint, withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: pixels, height: pixels) // ピクセル = ポイント（@1x）
    return rep.representation(using: .png, properties: [:])
}

// 各サイズを生成
let iconDir = "Clicher/Assets.xcassets/AppIcon.appiconset"
let specs: [(name: String, pixels: Int)] = [
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

for spec in specs {
    guard let data = renderIcon(pixels: spec.pixels) else {
        print("ERROR: Failed to render \(spec.name)")
        continue
    }
    try! data.write(to: URL(fileURLWithPath: "\(iconDir)/\(spec.name)"))
}

// 検証
for spec in specs {
    let url = URL(fileURLWithPath: "\(iconDir)/\(spec.name)")
    if let rep = NSBitmapImageRep(data: try! Data(contentsOf: url)) {
        print("\(spec.name): \(rep.pixelsWide)x\(rep.pixelsHigh) (expect \(spec.pixels)x\(spec.pixels)) \(rep.pixelsWide == spec.pixels ? "✓" : "✗ WRONG")")
    }
}
