package com.example.performance_guard

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/** Main plugin class for Android implementation */
class PerformanceGuardPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var anrWatchdog: AnrWatchdog? = null
    private var choreographerMonitor: ChoreographerMonitor? = null

    private val mainScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val ioScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var isMonitoring = false
    private var options: PerformanceOptions? = null

    companion object {
        const val METHOD_CHANNEL = "com.example.performance_guard/methods"
        const val EVENT_CHANNEL = "com.example.performance_guard/events"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopMonitoring()
        mainScope.cancel()
        ioScope.cancel()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val optionsMap = call.arguments<Map<String, Any>>() ?: emptyMap()
                options = PerformanceOptions.fromMap(optionsMap)
                startMonitoring()
                result.success(null)
            }
            "stop" -> {
                stopMonitoring()
                result.success(null)
            }
            "isMonitoring" -> {
                result.success(isMonitoring)
            }
            "getConfiguration" -> {
                result.success(options?.toMap())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startMonitoring() {
        if (isMonitoring) return

        val opts = options ?: return

        isMonitoring = true

        // Start ANR watchdog on IO dispatcher
        ioScope.launch {
            anrWatchdog = AnrWatchdog(
                freezeThresholdMs = opts.freezeThresholdMs,
                captureStackTraces = opts.captureStackTraces,
                onFreezeDetected = ::sendFreezeEvent
            )
            anrWatchdog?.start()
        }

        // Start Choreographer monitor on main dispatcher
        mainScope.launch {
            choreographerMonitor = ChoreographerMonitor(
                frameDropThresholdMs = opts.frameDropThresholdMs,
                onFrameDropDetected = ::sendFreezeEvent
            )
            choreographerMonitor?.start()
        }
    }

    private fun stopMonitoring() {
        anrWatchdog?.stop()
        choreographerMonitor?.stop()
        anrWatchdog = null
        choreographerMonitor = null
        isMonitoring = false
    }

    private fun sendFreezeEvent(event: FreezeEvent) {
        mainScope.launch {
            eventSink?.success(event.toMap())
        }
    }
}

/** Configuration options for Android monitoring */
data class PerformanceOptions(
    val freezeThresholdMs: Int,
    val frameDropThresholdMs: Int,
    val captureStackTraces: Boolean,
    val samplingIntervalMs: Int,
    val includeAppState: Boolean,
    val minimumReportDurationMs: Int
) {
    companion object {
        fun fromMap(map: Map<String, Any>): PerformanceOptions {
            return PerformanceOptions(
                freezeThresholdMs = map["freezeThresholdMs"] as? Int ?: 2000,
                frameDropThresholdMs = map["frameDropThresholdMs"] as? Int ?: 100,
                captureStackTraces = map["captureStackTraces"] as? Boolean ?: true,
                samplingIntervalMs = map["samplingIntervalMs"] as? Int ?: 500,
                includeAppState = map["includeAppState"] as? Boolean ?: true,
                minimumReportDurationMs = map["minimumReportDurationMs"] as? Int ?: 100
            )
        }
    }

    fun toMap(): Map<String, Any> {
        return mapOf(
            "freezeThresholdMs" to freezeThresholdMs,
            "frameDropThresholdMs" to frameDropThresholdMs,
            "captureStackTraces" to captureStackTraces,
            "samplingIntervalMs" to samplingIntervalMs,
            "includeAppState" to includeAppState,
            "minimumReportDurationMs" to minimumReportDurationMs
        )
    }
}

/** Freeze event data class */
data class FreezeEvent(
    val freezeDurationMs: Int,
    val timestamp: Long,
    val stackTrace: String?,
    val threadName: String,
    val platform: String = "android",
    val type: String,
    val metadata: Map<String, Any>? = null
) {
    fun toMap(): Map<String, Any> {
        val map = mutableMapOf<String, Any>(
            "freezeDurationMs" to freezeDurationMs,
            "timestamp" to timestamp,
            "threadName" to threadName,
            "platform" to platform,
            "type" to type
        )
        stackTrace?.let { map["stackTrace"] = it }
        metadata?.let { map["metadata"] = it }
        return map
    }
}
