package com.example.performance_guard

import android.os.SystemClock
import android.view.Choreographer
import kotlinx.coroutines.*
import kotlin.math.max

/**
 * Monitors frame rendering using Choreographer to detect frame drops
 *
 * Implements FrameCallback to measure the time between frame presentations.
 * When a frame takes longer than the threshold, a freeze event is reported.
 */
class ChoreographerMonitor(
    private val frameDropThresholdMs: Int,
    private val onFrameDropDetected: (FreezeEvent) -> Unit
) {
    private val monitorScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val choreographer = Choreographer.getInstance()
    private var isRunning = false
    private var lastFrameTime = 0L

    // Target frame interval (16ms for 60fps)
    private val targetFrameIntervalMs = 16L

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!isRunning) return

            val frameTimeMs = frameTimeNanos / 1_000_000 // Convert to ms
            val currentTime = SystemClock.uptimeMillis()

            if (lastFrameTime > 0) {
                val frameDuration = max(0, currentTime - lastFrameTime)
                val droppedTime = frameDuration - targetFrameIntervalMs

                if (droppedTime >= frameDropThresholdMs) {
                    reportFrameDrop(droppedTime.toInt(), frameDuration.toInt())
                }
            }

            lastFrameTime = currentTime

            // Continue monitoring
            if (isRunning) {
                choreographer.postFrameCallback(this)
            }
        }
    }

    fun start() {
        if (isRunning) return
        isRunning = true
        lastFrameTime = 0L
        choreographer.postFrameCallback(frameCallback)
    }

    fun stop() {
        isRunning = false
        choreographer.removeFrameCallback(frameCallback)
        monitorScope.cancel()
    }

    private fun reportFrameDrop(droppedTimeMs: Int, totalFrameDurationMs: Int) {
        val event = FreezeEvent(
            freezeDurationMs = droppedTimeMs,
            timestamp = System.currentTimeMillis(),
            stackTrace = null, // Frame drops don't have stack traces
            threadName = "main",
            type = "frame_drop",
            metadata = mapOf(
                "totalFrameDurationMs" to totalFrameDurationMs,
                "targetFrameIntervalMs" to targetFrameIntervalMs,
                "droppedFrames" to (droppedTimeMs / targetFrameIntervalMs.toInt())
            )
        )

        onFrameDropDetected(event)
    }
}
