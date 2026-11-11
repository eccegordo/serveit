// Draws the ServeIt app icon as a 1024x1024 PNG.
// Usage: swift scripts/make-icon.swift <output.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [
        CGFloat((hex >> 16) & 0xFF) / 255,
        CGFloat((hex >> 8) & 0xFF) / 255,
        CGFloat(hex & 0xFF) / 255,
        alpha,
    ])!
}

func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// Note: CoreGraphics origin is bottom-left.

// MARK: Background tile (standard macOS icon shape: 824pt tile on a 1024 canvas)
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = rounded(tile, 186)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(tilePath)
ctx.setFillColor(color(0x3B4FE0))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let background = CGGradient(colorsSpace: space,
                            colors: [color(0x35D0F7), color(0x3D7BF2), color(0x4338CA)] as CFArray,
                            locations: [0, 0.5, 1])!
ctx.drawLinearGradient(background,
                       start: CGPoint(x: tile.minX, y: tile.maxY),
                       end: CGPoint(x: tile.maxX, y: tile.minY),
                       options: [])
// Soft highlight at the top of the tile.
let highlight = CGGradient(colorsSpace: space,
                           colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray,
                           locations: [0, 1])!
ctx.drawLinearGradient(highlight,
                       start: CGPoint(x: 512, y: tile.maxY),
                       end: CGPoint(x: 512, y: tile.midY),
                       options: [])
ctx.restoreGState()

// MARK: Browser window
let window = CGRect(x: 212, y: 282, width: 600, height: 460)
let windowPath = rounded(window, 48)
let titleBarHeight: CGFloat = 92

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: color(0x0B1A5E, 0.45))
ctx.addPath(windowPath)
ctx.setFillColor(color(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()

// Title bar
ctx.saveGState()
ctx.addPath(windowPath)
ctx.clip()
ctx.setFillColor(color(0xE6ECF7))
ctx.fill(CGRect(x: window.minX, y: window.maxY - titleBarHeight,
                width: window.width, height: titleBarHeight))
ctx.restoreGState()

// Traffic lights
let lightsY = window.maxY - titleBarHeight / 2
for (index, hex) in [UInt32(0xFF5F57), 0xFEBC2E, 0x28C840].enumerated() {
    let centerX = window.minX + 58 + CGFloat(index) * 50
    ctx.setFillColor(color(hex))
    ctx.fillEllipse(in: CGRect(x: centerX - 16, y: lightsY - 16, width: 32, height: 32))
}

// Address bar
ctx.addPath(rounded(CGRect(x: window.minX + 200, y: lightsY - 21, width: 352, height: 42), 21))
ctx.setFillColor(color(0xFFFFFF))
ctx.fillPath()

// MARK: Toggle switch, in the "on" position
let contentMidY = (window.minY + window.maxY - titleBarHeight) / 2
let track = CGRect(x: 512 - 160, y: contentMidY - 82, width: 320, height: 164)
let trackPath = rounded(track, 82)

ctx.saveGState()
ctx.addPath(trackPath)
ctx.clip()
let green = CGGradient(colorsSpace: space,
                       colors: [color(0x4ADE80), color(0x22B755)] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(green,
                       start: CGPoint(x: 512, y: track.maxY),
                       end: CGPoint(x: 512, y: track.minY),
                       options: [])
ctx.restoreGState()

let knobRadius: CGFloat = 68
let knobCenter = CGPoint(x: track.maxX - 82, y: track.midY)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x000000, 0.28))
ctx.setFillColor(color(0xFFFFFF))
ctx.fillEllipse(in: CGRect(x: knobCenter.x - knobRadius, y: knobCenter.y - knobRadius,
                           width: knobRadius * 2, height: knobRadius * 2))
ctx.restoreGState()

// MARK: Write PNG
guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("failed to write \(output.path)\n".data(using: .utf8)!)
    exit(1)
}
