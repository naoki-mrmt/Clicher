#!/usr/bin/env swift

import AppKit
import CoreText
import Foundation

let size = 1024
let fontPath = "font/kateru_font_ver1.0-Regular.otf"

// フォント登録
let fontURL = URL(fileURLWithPath: fontPath)
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)

let families = CTFontManagerCopyAvailableFontFamilyNames() as! [String]
let kateruFamily = families.first { $0.lowercased().contains("kateru") }
print("Font family: \(kateruFamily ?? "not found")")

let fontName = kateruFamily ?? "Helvetica"
guard let font = NSFont(name: fontName, size: CGFloat(size) * 0.18) else {
    print("ERROR: Could not create font")
    exit(1)
}

let imageSize = NSSize(width: size, height: size)
let image = NSImage(size: imageSize)
image.lockFocus()

let bgRect = NSRect(origin: .zero, size: imageSize)
let cornerRadius: CGFloat = CGFloat(size) * 0.22

let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
bgPath.addClip()

// 背景: 白
NSColor.white.setFill()
bgPath.fill()

// "Clicher" の文字を描画（黒）
let text = "Clicher" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black,
]
let textSize = text.size(withAttributes: attrs)
let textPoint = NSPoint(
    x: (CGFloat(size) - textSize.width) / 2,
    y: (CGFloat(size) - textSize.height) / 2 - CGFloat(size) * 0.02
)
text.draw(at: textPoint, withAttributes: attrs)

image.unlockFocus()

// PNG 保存
guard let tiffData = image.tiffRepresentation,
      let bitmapRep = NSBitmapImageRep(data: tiffData),
      let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    print("ERROR: Could not create PNG")
    exit(1)
}

let outputPath = "build/AppIcon.png"
try! FileManager.default.createDirectory(atPath: "build", withIntermediateDirectories: true)
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Icon saved to \(outputPath)")

// iconset 作成
let iconsetPath = "build/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let sizes = [16, 32, 64, 128, 256, 512]
for s in sizes {
    for scale in [1, 2] {
        let pixelSize = s * scale
        let resized = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
        resized.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { continue }

        let suffix = scale == 2 ? "@2x" : ""
        try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/icon_\(s)x\(s)\(suffix).png"))
    }
}

print("Iconset created. Converting to icns...")
