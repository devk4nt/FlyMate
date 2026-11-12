import AppKit
import AVFoundation
import CoreImage
import CoreMedia
import QuartzCore

enum ReelError: Error {
    case missingVideoTrack(String)
    case cannotCreateCompositionTrack
    case exportFailed(String)
    case imageLoadFailed(String)
}

let root = URL(fileURLWithPath: "/Users/jaejun/FlyMate")
let reelDirectory = root.appendingPathComponent("Deliverables/Marketing/InstagramReels-2026-08")
let clipURLs = [
    reelDirectory.appendingPathComponent("clip-home-to-recruit.mp4"),
    reelDirectory.appendingPathComponent("clip-notifications.mp4")
]
let clipStartSeconds = [6.5, 15.5]
let clipDurationSeconds = [8.5, 7.0]
let baseOutputURL = reelDirectory.appendingPathComponent("FlyMate-Recruit-Notification-Reel-Base.mp4")
let outputURL = reelDirectory.appendingPathComponent("FlyMate-Recruit-Notification-Reel.mp4")
let coverSourceURL = root.appendingPathComponent("Deliverables/Marketing/InstagramProfileRefresh-2026-08/04-recruit-notification.png")
let coverURL = reelDirectory.appendingPathComponent("FlyMate-Recruit-Notification-Reel-Cover.png")

func normalizedTransform(for track: AVAssetTrack, target: CGRect) -> CGAffineTransform {
    let preferred = track.preferredTransform
    let transformedRect = CGRect(origin: .zero, size: track.naturalSize).applying(preferred)
    let displaySize = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))
    let scale = min(target.width / displaySize.width, target.height / displaySize.height)
    let fittedSize = CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
    let origin = CGPoint(
        x: target.midX - fittedSize.width / 2,
        y: target.midY - fittedSize.height / 2
    )

    return preferred
        .concatenating(CGAffineTransform(translationX: -transformedRect.minX, y: -transformedRect.minY))
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        .concatenating(CGAffineTransform(translationX: origin.x, y: origin.y))
}

func addTimedText(
    _ text: String,
    frame: CGRect,
    fontSize: CGFloat,
    color: NSColor,
    start: Double,
    end: Double,
    to parent: CALayer
) {
    let layer = CATextLayer()
    layer.frame = frame
    layer.string = text
    layer.alignmentMode = .center
    layer.contentsScale = 3
    layer.foregroundColor = color.cgColor
    layer.font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
    layer.fontSize = fontSize
    layer.isWrapped = true
    layer.opacity = 0

    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.values = [0, 1, 1, 0]
    animation.keyTimes = [0, 0.08, 0.90, 1]
    animation.beginTime = AVCoreAnimationBeginTimeAtZero + start
    animation.duration = max(0.5, end - start)
    animation.fillMode = .both
    animation.isRemovedOnCompletion = false
    layer.add(animation, forKey: "visibility")
    parent.addSublayer(layer)
}

func createCover() throws {
    guard let source = NSImage(contentsOf: coverSourceURL) else {
        throw ReelError.imageLoadFailed(coverSourceURL.path)
    }

    let size = NSSize(width: 1080, height: 1920)
    let image = NSImage(size: size)
    image.lockFocus()

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.94, green: 0.98, blue: 1.0, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.96, alpha: 1)
    ])
    gradient?.draw(in: NSRect(origin: .zero, size: size), angle: -20)

    let titleStyle = NSMutableParagraphStyle()
    titleStyle.alignment = .center
    let eyebrow: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 34, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.45, blue: 0.72, alpha: 1),
        .paragraphStyle: titleStyle
    ]
    let title: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 68, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1),
        .paragraphStyle: titleStyle
    ]

    NSString(string: "NEW STUDY ALERT").draw(in: NSRect(x: 80, y: 1725, width: 920, height: 60), withAttributes: eyebrow)
    NSString(string: "새 모집글,\n알림으로 바로 확인").draw(in: NSRect(x: 70, y: 1530, width: 940, height: 180), withAttributes: title)

    let imageRect = NSRect(x: 160, y: 300, width: 760, height: 950)
    let sourceRect = NSRect(origin: .zero, size: source.size)
    source.draw(in: imageRect, from: sourceRect, operation: .sourceOver, fraction: 1)
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw ReelError.imageLoadFailed("cover render")
    }
    try png.write(to: coverURL)
}

func makeCaptionOverlay(_ text: String) throws -> CIImage {
    let size = NSSize(width: 1080, height: 1920)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    let panelRect = NSRect(x: 55, y: 1510, width: 970, height: 280)
    let panel = NSBezierPath(roundedRect: panelRect, xRadius: 42, yRadius: 42)
    NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 0.97).setFill()
    panel.fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let brandAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 0.04, green: 0.46, blue: 0.72, alpha: 1),
        .paragraphStyle: paragraph
    ]
    let captionAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 47, weight: .bold),
        .foregroundColor: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1),
        .paragraphStyle: paragraph
    ]
    NSString(string: "FlyMate · STUDY ALERT").draw(
        in: NSRect(x: 80, y: 1720, width: 920, height: 40),
        withAttributes: brandAttributes
    )
    NSString(string: text).draw(
        in: NSRect(x: 80, y: 1555, width: 920, height: 135),
        withAttributes: captionAttributes
    )
    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let cgImage = bitmap.cgImage
    else {
        throw ReelError.imageLoadFailed("caption overlay")
    }
    let ciImage = CIImage(cgImage: cgImage)
    let scaleX = 1080 / ciImage.extent.width
    let scaleY = 1920 / ciImage.extent.height
    return ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
}

let composition = AVMutableComposition()
guard let compositionTrack = composition.addMutableTrack(
    withMediaType: .video,
    preferredTrackID: kCMPersistentTrackID_Invalid
) else {
    throw ReelError.cannotCreateCompositionTrack
}

var cursor = CMTime.zero
var instructions: [AVMutableVideoCompositionInstruction] = []
var totalSeconds = 0.0

for (index, clipURL) in clipURLs.enumerated() {
    let asset = AVURLAsset(url: clipURL)
    let assetDuration = try await asset.load(.duration)
    let tracks = try await asset.loadTracks(withMediaType: .video)
    guard let sourceTrack = tracks.first else {
        throw ReelError.missingVideoTrack(clipURL.path)
    }

    let sourceStart = CMTime(seconds: clipStartSeconds[index], preferredTimescale: 600)
    let requestedDuration = CMTime(seconds: clipDurationSeconds[index], preferredTimescale: 600)
    let availableDuration = CMTimeSubtract(assetDuration, sourceStart)
    let duration = CMTimeMinimum(requestedDuration, availableDuration)

    try compositionTrack.insertTimeRange(
        CMTimeRange(start: sourceStart, duration: duration),
        of: sourceTrack,
        at: cursor
    )

    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: cursor, duration: duration)
    instruction.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.99, alpha: 1).cgColor

    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
    let targetRect = CGRect(x: 240, y: 120, width: 600, height: 1300)
    layerInstruction.setTransform(normalizedTransform(for: sourceTrack, target: targetRect), at: cursor)
    instruction.layerInstructions = [layerInstruction]
    instructions.append(instruction)

    cursor = CMTimeAdd(cursor, duration)
    totalSeconds += duration.seconds
}

let videoComposition = AVMutableVideoComposition()
videoComposition.renderSize = CGSize(width: 1080, height: 1920)
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.instructions = instructions

let parentLayer = CALayer()
parentLayer.frame = CGRect(x: 0, y: 0, width: 1080, height: 1920)

let backgroundLayer = CAGradientLayer()
backgroundLayer.frame = parentLayer.bounds
backgroundLayer.colors = [
    NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 1).cgColor,
    NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.96, alpha: 1).cgColor
]
backgroundLayer.startPoint = CGPoint(x: 0, y: 1)
backgroundLayer.endPoint = CGPoint(x: 1, y: 0)
parentLayer.addSublayer(backgroundLayer)

let phoneShadow = CALayer()
phoneShadow.frame = CGRect(x: 224, y: 104, width: 632, height: 1332)
phoneShadow.backgroundColor = NSColor.white.cgColor
phoneShadow.cornerRadius = 54
phoneShadow.shadowColor = NSColor.black.cgColor
phoneShadow.shadowOpacity = 0.16
phoneShadow.shadowRadius = 28
phoneShadow.shadowOffset = CGSize(width: 0, height: -10)
parentLayer.addSublayer(phoneShadow)

let videoLayer = CALayer()
videoLayer.frame = parentLayer.bounds
parentLayer.addSublayer(videoLayer)

let brandLayer = CATextLayer()
brandLayer.frame = CGRect(x: 40, y: 1810, width: 1000, height: 54)
brandLayer.string = "FlyMate  ·  STUDY ALERT"
brandLayer.alignmentMode = .center
brandLayer.contentsScale = 3
brandLayer.foregroundColor = NSColor(calibratedRed: 0.04, green: 0.45, blue: 0.72, alpha: 1).cgColor
brandLayer.font = NSFont.systemFont(ofSize: 30, weight: .semibold)
brandLayer.fontSize = 30
parentLayer.addSublayer(brandLayer)

let segment = totalSeconds / 4
addTimedText("스터디 모집글, 매번 직접 확인하고 있나요?", frame: CGRect(x: 70, y: 1705, width: 940, height: 100), fontSize: 49, color: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1), start: 0, end: segment, to: parentLayer)
addTimedText("새 모집글을 한곳에서 보고", frame: CGRect(x: 70, y: 1705, width: 940, height: 100), fontSize: 49, color: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1), start: segment, end: segment * 2, to: parentLayer)
addTimedText("알림으로 바로 확인하세요", frame: CGRect(x: 70, y: 1705, width: 940, height: 100), fontSize: 49, color: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1), start: segment * 2, end: segment * 3, to: parentLayer)
addTimedText("확인하는 시간은 줄이고, 면접 연습에 더 집중 ✈️", frame: CGRect(x: 65, y: 1700, width: 950, height: 110), fontSize: 44, color: NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.38, alpha: 1), start: segment * 3, end: totalSeconds, to: parentLayer)

videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
    postProcessingAsVideoLayer: videoLayer,
    in: parentLayer
)

try? FileManager.default.removeItem(at: baseOutputURL)
guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
    throw ReelError.exportFailed("export session")
}
exporter.videoComposition = videoComposition
do {
    try await exporter.export(to: baseOutputURL, as: .mp4)
} catch {
    let nsError = error as NSError
    throw ReelError.exportFailed("\(nsError.domain) \(nsError.code): \(nsError.localizedDescription) \(nsError.userInfo)")
}

let captions = [
    "스터디 모집글, 매번 직접 확인하고 있나요?",
    "새 모집글을 한곳에서 보고",
    "알림으로 바로 확인하세요",
    "확인하는 시간은 줄이고, 면접 연습에 더 집중 ✈️"
]
let overlays = try captions.map(makeCaptionOverlay)
let baseAsset = AVURLAsset(url: baseOutputURL)
let captionedComposition = AVVideoComposition(asset: baseAsset) { request in
    let seconds = request.compositionTime.seconds
    let index = min(3, max(0, Int(seconds / segment)))
    let source = request.sourceImage.clampedToExtent()
    let composed = overlays[index].composited(over: source).cropped(to: request.sourceImage.extent)
    request.finish(with: composed, context: nil)
}

try? FileManager.default.removeItem(at: outputURL)
guard let captionExporter = AVAssetExportSession(asset: baseAsset, presetName: AVAssetExportPresetHighestQuality) else {
    throw ReelError.exportFailed("caption export session")
}
captionExporter.videoComposition = captionedComposition
do {
    try await captionExporter.export(to: outputURL, as: .mp4)
} catch {
    let nsError = error as NSError
    throw ReelError.exportFailed("caption export: \(nsError.domain) \(nsError.code): \(nsError.localizedDescription) \(nsError.userInfo)")
}

try createCover()
print(outputURL.path)
print(coverURL.path)
