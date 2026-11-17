import AppKit
import Foundation
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (points, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let pixels = points * scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    NSColor(calibratedRed: 0.10, green: 0.25, blue: 0.34, alpha: 1).setFill()
    let inset = CGFloat(pixels) * 0.08
    NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: CGFloat(pixels)-2*inset, height: CGFloat(pixels)-2*inset), xRadius: CGFloat(pixels)*0.19, yRadius: CGFloat(pixels)*0.19).fill()
    let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: CGFloat(pixels)*0.38, weight: .semibold), .foregroundColor: NSColor(calibratedRed:0.88,green:0.95,blue:0.98,alpha:1), .paragraphStyle: paragraph]
    let label = "HP" as NSString
    let size = label.size(withAttributes: attributes)
    label.draw(in: NSRect(x:0,y:(CGFloat(pixels)-size.height)/2,width:CGFloat(pixels),height:size.height), withAttributes:attributes)
    image.unlockFocus()
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let suffix = scale == 2 ? "@2x" : ""
    try rep.representation(using:.png,properties:[:])!.write(to: directory.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
}
