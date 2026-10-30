import AppKit
import AVFoundation

let videoURL = URL(fileURLWithPath: "/Users/jaejun/FlyMate/Deliverables/Marketing/InstagramReels-2026-08/FlyMate-Recruit-Notification-Reel.mp4")
let outputURL = URL(fileURLWithPath: "/Users/jaejun/FlyMate/Deliverables/Marketing/InstagramReels-2026-08/reel-contact-sheet.png")
for name in ["clip-home-to-recruit.mp4", "clip-notifications.mp4"] {
    let rawAsset = AVURLAsset(url: videoURL.deletingLastPathComponent().appendingPathComponent(name))
    print("\(name)=\(try await rawAsset.load(.duration).seconds)")
}
let asset = AVURLAsset(url: videoURL)
let duration = try await asset.load(.duration).seconds
if let track = try await asset.loadTracks(withMediaType: .video).first {
    print("size=\(try await track.load(.naturalSize)) transform=\(try await track.load(.preferredTransform))")
}
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 270, height: 480)
let fractions = [0.08, 0.28, 0.48, 0.68, 0.88]
let sheet = NSImage(size: NSSize(width: 1350, height: 480))
sheet.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: 1350, height: 480).fill()

for (index, fraction) in fractions.enumerated() {
    let time = CMTime(seconds: duration * fraction, preferredTimescale: 600)
    let result = try await generator.image(at: time)
    let image = NSImage(cgImage: result.image, size: NSSize(width: 270, height: 480))
    image.draw(in: NSRect(x: CGFloat(index) * 270, y: 0, width: 270, height: 480))
}

sheet.unlockFocus()
guard
    let tiff = sheet.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to create contact sheet")
}
try png.write(to: outputURL)
print("final=\(duration)")
print(outputURL.path)
