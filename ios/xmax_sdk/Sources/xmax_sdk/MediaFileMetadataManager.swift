import AVFoundation
import Flutter
import ImageIO

/// Metadata-only storage diagnostics. Never allocates a decoded image/video frame.
final class MediaFileMetadataManager: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "ai.xmax.sdk/media",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(MediaFileMetadataManager(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "readResolution" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let arguments = call.arguments as? [String: Any] else {
            result(nil)
            return
        }

        let fileURL = (arguments["filePath"] as? String).map { URL(fileURLWithPath: $0) }
        if arguments["mediaType"] as? String == "video" {
            Task {
                let resolution = await Self.videoResolution(fileURL)
                await MainActor.run { result(resolution) }
            }
        } else {
            let data = (arguments["data"] as? FlutterStandardTypedData)?.data
            DispatchQueue.global(qos: .utility).async {
                let resolution = Self.imageResolution(data: data, fileURL: fileURL)
                DispatchQueue.main.async { result(resolution) }
            }
        }
    }

    private static func imageResolution(data: Data?, fileURL: URL?) -> [String: Int]? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        let source: CGImageSource?
        if let data {
            source = CGImageSourceCreateWithData(data as CFData, options)
        } else if let fileURL {
            source = CGImageSourceCreateWithURL(fileURL as CFURL, options)
        } else {
            return nil
        }
        guard let source,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        return ["width": width.intValue, "height": height.intValue]
    }

    private static func videoResolution(_ fileURL: URL?) async -> [String: Int]? {
        guard let fileURL else { return nil }
        do {
            let asset = AVURLAsset(url: fileURL)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { return nil }
            let size = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let displaySize = size.applying(transform)
            guard displaySize.width.isFinite, displaySize.height.isFinite else { return nil }
            return [
                "width": Int(abs(displaySize.width).rounded()),
                "height": Int(abs(displaySize.height).rounded())
            ]
        } catch {
            return nil
        }
    }
}
