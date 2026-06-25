import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Re-encode each PNG with NO alpha channel (opaque RGB), in place.
// App Store Connect rejects screenshots that contain an alpha channel,
// even when every pixel is fully opaque (Chrome saves RGBA).

func flatten(_ path: String) -> Bool {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let src = CGImageSourceCreateWithURL(url, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        FileHandle.standardError.write("  ✗ could not read \(path)\n".data(using: .utf8)!)
        return false
    }
    let w = img.width, h = img.height
    let cs = CGColorSpaceCreateDeviceRGB()
    // 8-bit RGB, alpha = none(skip) → resulting PNG has no alpha channel.
    guard let ctx = CGContext(data: nil, width: w, height: h,
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let out = ctx.makeImage(),
          let dst = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dst, out, nil)
    return CGImageDestinationFinalize(dst)
}

let files = Array(CommandLine.arguments.dropFirst())
var ok = 0
for f in files where flatten(f) { ok += 1 }
print("flattened \(ok)/\(files.count) image(s)")
