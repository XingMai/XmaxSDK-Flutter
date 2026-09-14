import Flutter
import Foundation
import OSLog

/// Automatically registered by Flutter; no host AppDelegate setup is needed.
public final class XmaxSDKPlugin: NSObject, FlutterPlugin {
    private static let logger = Logger(
        subsystem: "ai.xmax.XmaxSDK",
        category: "XmaxSDK"
    )

    public static func register(with registrar: FlutterPluginRegistrar) {
        MediaFileMetadataManager.register(with: registrar)
        let channel = FlutterMethodChannel(
            name: "ai.xmax.sdk/logging",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(XmaxSDKPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "log" else {
            result(FlutterMethodNotImplemented)
            return
        }
        guard let arguments = call.arguments as? [String: Any],
              let level = arguments["level"] as? String,
              let message = arguments["message"] as? String,
              ["debug", "info", "warning", "error"].contains(level) else {
            result(FlutterError(code: "invalid_arguments", message: "Invalid log record", details: nil))
            return
        }

        // Dart already applies loggerOptions and formats each line's category.
        // Match native XmaxSDK's public log text; callers must not log secrets.
        // Emit lines individually so multiline RTC statistics remain readable.
        for line in message.components(separatedBy: "\n") {
            switch level {
            case "debug": Self.logger.debug("\(line, privacy: .public)")
            case "info": Self.logger.info("\(line, privacy: .public)")
            case "warning": Self.logger.warning("\(line, privacy: .public)")
            default: Self.logger.error("\(line, privacy: .public)")
            }
        }
        result(nil)
    }
}
