import Flutter
import UIKit
import Foundation

/// Main plugin class for iOS implementation
public class PerformanceGuardPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private var runLoopMonitor: RunLoopMonitor?
    private var isMonitoring = false
    private var options: PerformanceOptions?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = PerformanceGuardPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "com.example.performance_guard/methods",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel = methodChannel
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "com.example.performance_guard/events",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel = eventChannel

        let streamHandler = FreezeEventStreamHandler()
        eventChannel.setStreamHandler(streamHandler)
        instance.eventSink = streamHandler.eventSink
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS",
                                   message: "Invalid arguments",
                                   details: nil))
                return
            }
            options = PerformanceOptions(from: args)
            startMonitoring()
            result(nil)

        case "stop":
            stopMonitoring()
            result(nil)

        case "isMonitoring":
            result(isMonitoring)

        case "getConfiguration":
            result(options?.toDictionary())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startMonitoring() {
        guard !isMonitoring, let opts = options else { return }

        isMonitoring = true

        runLoopMonitor = RunLoopMonitor(
            stallThresholdMs: opts.freezeThresholdMs,
            captureStackTraces: opts.captureStackTraces,
            onStallDetected: { [weak self] event in
                self?.sendFreezeEvent(event)
            }
        )
        runLoopMonitor?.start()
    }

    private func stopMonitoring() {
        runLoopMonitor?.stop()
        runLoopMonitor = nil
        isMonitoring = false
    }

    private func sendFreezeEvent(_ event: FreezeEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event.toDictionary())
        }
    }
}

/// Stream handler for freeze events
class FreezeEventStreamHandler: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}

/// Configuration options for iOS monitoring
struct PerformanceOptions {
    let freezeThresholdMs: Int
    let frameDropThresholdMs: Int
    let captureStackTraces: Bool
    let samplingIntervalMs: Int
    let includeAppState: Bool
    let minimumReportDurationMs: Int

    init(from dictionary: [String: Any]) {
        self.freezeThresholdMs = dictionary["freezeThresholdMs"] as? Int ?? 2000
        self.frameDropThresholdMs = dictionary["frameDropThresholdMs"] as? Int ?? 100
        self.captureStackTraces = dictionary["captureStackTraces"] as? Bool ?? true
        self.samplingIntervalMs = dictionary["samplingIntervalMs"] as? Int ?? 500
        self.includeAppState = dictionary["includeAppState"] as? Bool ?? true
        self.minimumReportDurationMs = dictionary["minimumReportDurationMs"] as? Int ?? 100
    }

    func toDictionary() -> [String: Any] {
        return [
            "freezeThresholdMs": freezeThresholdMs,
            "frameDropThresholdMs": frameDropThresholdMs,
            "captureStackTraces": captureStackTraces,
            "samplingIntervalMs": samplingIntervalMs,
            "includeAppState": includeAppState,
            "minimumReportDurationMs": minimumReportDurationMs
        ]
    }
}

/// Freeze event data structure
struct FreezeEvent {
    let freezeDurationMs: Int
    let timestamp: Int64
    let stackTrace: String?
    let threadName: String
    let platform: String
    let type: String
    let metadata: [String: Any]?

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "freezeDurationMs": freezeDurationMs,
            "timestamp": timestamp,
            "threadName": threadName,
            "platform": platform,
            "type": type
        ]
        if let stackTrace = stackTrace {
            dict["stackTrace"] = stackTrace
        }
        if let metadata = metadata {
            dict["metadata"] = metadata
        }
        return dict
    }
}
