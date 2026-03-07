package com.example.performance_guard

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import kotlinx.coroutines.*

/**
 * ANR Watchdog that monitors the main thread message queue
 *
 * Uses a background thread to post tasks to the main looper and measures
 * the time it takes for them to execute. If the delay exceeds the threshold,
 * an ANR is detected.
 */
class AnrWatchdog(
    private val freezeThresholdMs: Int,
    private val captureStackTraces: Boolean,
    private val onFreezeDetected: (FreezeEvent) -> Unit,
    private val samplingIntervalMs: Int = 500
) {
    private val watchdogScope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isRunning = false
    private var lastUiThreadTime = 0L

    fun start() {
        if (isRunning) return
        isRunning = true

        watchdogScope.launch {
            monitorForAnr()
        }
    }

    fun stop() {
        isRunning = false
        watchdogScope.cancel()
    }

    private suspend fun monitorForAnr() {
        while (isRunning) {
            val beforePost = SystemClock.uptimeMillis()
            lastUiThreadTime = beforePost

            // Post a task to main thread
            val barrier = CompletableDeferred<Unit>()

            withContext(Dispatchers.Main) {
                mainHandler.post {
                    lastUiThreadTime = SystemClock.uptimeMillis()
                    barrier.complete(Unit)
                }
            }

            // Wait for the task to execute with timeout
            val timeoutResult = withTimeoutOrNull(freezeThresholdMs.toLong()) {
                barrier.await()
            }

            if (timeoutResult == null) {
                // Task didn't execute within threshold - ANR detected
                val actualDelay = SystemClock.uptimeMillis() - beforePost
                reportAnr(actualDelay.toInt())
            } else {
                // Calculate actual delay even if within threshold
                val actualDelay = lastUiThreadTime - beforePost
                if (actualDelay > freezeThresholdMs) {
                    reportAnr(actualDelay.toInt())
                }
            }

            delay(samplingIntervalMs.toLong())
        }
    }

    private fun reportAnr(durationMs: Int) {
        val stackTrace = if (captureStackTraces) {
            getMainThreadStackTrace()
        } else null

        val event = FreezeEvent(
            freezeDurationMs = durationMs,
            timestamp = System.currentTimeMillis(),
            stackTrace = stackTrace,
            threadName = "main",
            type = "anr",
            metadata = mapOf(
                "samplingIntervalMs" to samplingIntervalMs,
                "thresholdMs" to freezeThresholdMs
            )
        )

        onFreezeDetected(event)
    }

    private fun getMainThreadStackTrace(): String {
        val mainThread = Looper.getMainLooper().thread
        val stackTrace = mainThread.stackTrace

        return buildString {
            appendLine("Main Thread Stack Trace:")
            appendLine("Thread: ${mainThread.name} (ID: ${mainThread.id})")
            appendLine("State: ${mainThread.state}")
            appendLine("---")
            stackTrace.forEach { element ->
                appendLine("\tat $element")
            }
        }
    }
}
