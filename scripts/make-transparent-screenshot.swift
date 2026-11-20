// Convert a real window capture to PNG with transparent outer padding.
// The UI is not generated, scaled, recolored or retouched.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else {
    fputs("Usage: make-transparent-screenshot input.jpg output.png\n", stderr)
    exit(2)
}
let inputURL = URL(fileURLWithPath: args[1])
let outputURL = URL(fileURLWithPath: args[2])
guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Cannot decode screenshot") }
let width = image.width, height = image.height
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
var original = [UInt8](repeating: 0, count: width * height * 4)
original.withUnsafeMutableBytes { data in
    let context = CGContext(data: data.baseAddress, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width * 4, space: space, bitmapInfo: bitmapInfo)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
}
let margin = 48
let radius = 36.0
let outWidth = width + 2 * margin, outHeight = height + 2 * margin
var output = [UInt8](repeating: 0, count: outWidth * outHeight * 4)
var opaqueCopied = 0
for y in 0..<height {
    for x in 0..<width {
        let dx = min(Double(x) + 0.5, Double(width - x) - 0.5)
        let dy = min(Double(y) + 0.5, Double(height - y) - 0.5)
        var coverage = 1.0
        if dx < radius && dy < radius {
            coverage = min(1, max(0, radius + 0.5 - hypot(radius - dx, radius - dy)))
        }
        let src = (y * width + x) * 4
        let dst = ((y + margin) * outWidth + x + margin) * 4
        if coverage == 1 {
            for channel in 0..<4 { output[dst + channel] = original[src + channel] }
            opaqueCopied += 1
        } else {
            for channel in 0..<4 { output[dst + channel] = UInt8((Double(original[src + channel]) * coverage).rounded()) }
        }
    }
}
let data = Data(output)
let provider = CGDataProvider(data: data as CFData)!
let png = CGImage(width: outWidth, height: outHeight, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: outWidth * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Cannot create PNG") }
CGImageDestinationAddImage(destination, png, nil)
precondition(CGImageDestinationFinalize(destination), "Cannot write PNG")
// Verify a decode of the written PNG preserves all pixels away from the clipped corners.
let savedSource = CGImageSourceCreateWithURL(outputURL as CFURL, nil)!
let savedImage = CGImageSourceCreateImageAtIndex(savedSource, 0, nil)!
var saved = [UInt8](repeating: 0, count: output.count)
saved.withUnsafeMutableBytes { bytes in
    let context = CGContext(data: bytes.baseAddress, width: outWidth, height: outHeight, bitsPerComponent: 8,
                            bytesPerRow: outWidth * 4, space: space, bitmapInfo: bitmapInfo)!
    context.draw(savedImage, in: CGRect(x: 0, y: 0, width: outWidth, height: outHeight))
}
for y in Int(radius)..<(height - Int(radius)) {
    for x in 0..<width {
        let src = (y * width + x) * 4, dst = ((y + margin) * outWidth + x + margin) * 4
        for channel in 0..<4 { precondition(saved[dst + channel] == original[src + channel], "Interior pixel changed") }
    }
}
precondition(saved[3] == 0 && saved[((margin + height / 2) * outWidth + margin + width / 2) * 4 + 3] == 255)
print("PASS: \(outputURL.lastPathComponent), \(outWidth)×\(outHeight), transparent background, \(opaqueCopied) original opaque pixels copied")
