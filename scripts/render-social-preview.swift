#!/usr/bin/env swift

import AppKit
import Foundation

let projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconURL = projectURL.appendingPathComponent("Resources/AppIcon.png")
let outputURL = projectURL.appendingPathComponent(".github/assets/social-preview.png")

guard let icon = NSImage(contentsOf: iconURL) else {
    fatalError("Unable to load \(iconURL.path)")
}

let size = NSSize(width: 1280, height: 640)
let image = NSImage(size: size)
image.lockFocus()

let backgroundRect = NSRect(origin: .zero, size: size)
let background = NSGradient(
    starting: NSColor(calibratedRed: 0.008, green: 0.020, blue: 0.035, alpha: 1),
    ending: NSColor(calibratedRed: 0.020, green: 0.080, blue: 0.105, alpha: 1)
)!
background.draw(in: backgroundRect, angle: 0)

let glow = NSBezierPath(ovalIn: NSRect(x: 5, y: 65, width: 520, height: 520))
NSColor(calibratedRed: 0.02, green: 0.58, blue: 0.78, alpha: 0.10).setFill()
glow.fill()

icon.draw(
    in: NSRect(x: 88, y: 104, width: 432, height: 432),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 78, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.91, green: 0.97, blue: 0.99, alpha: 1)
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.57, green: 0.70, blue: 0.75, alpha: 1)
]

NSAttributedString(string: "ImpactBar", attributes: titleAttributes)
    .draw(at: NSPoint(x: 560, y: 348))
NSAttributedString(
    string: "Combat-log overlays for EVE Online on macOS",
    attributes: subtitleAttributes
).draw(at: NSPoint(x: 566, y: 296))

let segmentColors = [
    NSColor(calibratedRed: 0.13, green: 0.72, blue: 0.88, alpha: 1),
    NSColor(calibratedRed: 0.88, green: 0.64, blue: 0.25, alpha: 1),
    NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.40, alpha: 1)
]
for index in 0..<3 {
    segmentColors[index].setFill()
    NSBezierPath(
        rect: NSRect(x: 568 + CGFloat(index * 164), y: 224, width: 146, height: 9)
    ).fill()
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render PNG")
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print(outputURL.path)
