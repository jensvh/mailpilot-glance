import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws the app's icon: the board at a glance. Three bars for three lanes in the colours they have in the app
// (amber waits on you, cyan works, violet is to review) and a lime dot for what is done, on the app's dark ground
// with a faint light from the top left. The build runs this on its Mac, so no picture is kept in the repository:
//
//   swift tools/icon/main.swift Sources/Assets.xcassets/AppIcon.appiconset/icon.png

let size = 1024
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let space = CGColorSpaceCreateDeviceRGB()

// No alpha: an app icon is opaque.
guard let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    print("could not make a drawing context")
    exit(1)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [red, green, blue, alpha])!
}

let ground = color(0.043, 0.047, 0.063)
let amber = color(0.96, 0.75, 0.36)
let cyan = color(0.37, 0.80, 0.95)
let violet = color(0.66, 0.60, 0.98)
let lime = color(0.62, 0.89, 0.45)

context.setFillColor(ground)
context.fill(CGRect(x: 0, y: 0, width: size, height: size))

// The light: violet near the top left, fading out. (The origin is at the bottom left.)
if let glow = CGGradient(colorsSpace: space, colors: [color(0.66, 0.60, 0.98, 0.42), color(0.37, 0.80, 0.95, 0.0)] as CFArray, locations: [0, 1]) {
    let centre = CGPoint(x: 300, y: 800)
    context.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 820, options: [])
}

func bar(y: CGFloat, width: CGFloat, _ fill: CGColor) {
    let rect = CGRect(x: 226, y: y, width: width, height: 132)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: 66, cornerHeight: 66, transform: nil))
    context.setFillColor(fill)
    context.fillPath()
}

bar(y: 656, width: 572, amber)
bar(y: 446, width: 372, cyan)
bar(y: 236, width: 472, violet)

// What is done: a dot beside the middle bar.
context.setFillColor(lime)
context.fillEllipse(in: CGRect(x: 666, y: 446, width: 132, height: 132))

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    print("could not make the picture")
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    print("could not write \(path)")
    exit(1)
}
print("icon written to \(path)")
