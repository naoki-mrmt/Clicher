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
guard let font = NSFont(name: fontName, size: CGFloat(masterSize) * 0.18) else {
    print("ERROR: Could not create font")
    exit(1)
}

// マスター画像生成 (1024x1024)
let imageSize = NSSize(width: masterSize, height: masterSize)
let masterImage = NSImage(size: imageSize)
masterImage.lockFocus()

let bgRect = NSRect(origin: .zero, size: imageSize)
let cornerRadius: CGFloat = CGFloat(masterSize) * 0.22
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
bgPath.addClip()

NSColor.white.setFill()
bgPath.fill()

let text = "Clicher" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.black,
]
let textSize = text.size(withAttributes: attrs)
let textPoint = NSPoint(
    x: (CGFloat(masterSize) - textSize.width) / 2,
    y: (CGFloat(masterSize) - textSize.height) / 2 - CGFloat(masterSize) * 0.02
)
text.draw(at: textPoint, withAttributes: attrs)

masterImage.unlockFocus()

// iconset 作成
let iconsetPath = "build/AppIcon.iconset"
let iconDir = "Clicher/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// 各サイズを正しいピクセルサイズで生成
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
    let resized = NSImage(size: NSSize(width: spec.pixels, height: spec.pixels))
    resized.lockFocus()
    masterImage.draw(in: NSRect(x: 0, y: 0, width: spec.pixels, height: spec.pixels))
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }

    try! png.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(spec.name)"))
    try! png.write(to: URL(fileURLWithPath: "\(iconDir)/\(spec.name)"))
}

print("Icons generated with correct pixel sizes")
print("Run: iconutil -c icns \(iconsetPath)")
