#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: svg2png <input.svg> <output.png> [size]\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let size = CommandLine.arguments.count > 3 ? (Int(CommandLine.arguments[3]) ?? 1024) : 1024

guard let svgData = FileManager.default.contents(atPath: inputPath),
      let svgImage = NSImage(data: svgData) else {
    fputs("Error: Failed to load SVG from \(inputPath)\n", stderr)
    exit(1)
}

let targetSize = NSSize(width: size, height: size)
guard let rep = NSBitmapImageRep(
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
) else {
    fputs("Error: Failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.set()
NSRect(origin: .zero, size: targetSize).fill()
svgImage.draw(in: NSRect(origin: .zero, size: targetSize),
              from: .zero, operation: .sourceOver, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let pngData = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
    fputs("Error: Failed to create PNG data\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("Error: Failed to write PNG: \(error)\n", stderr)
    exit(1)
}
