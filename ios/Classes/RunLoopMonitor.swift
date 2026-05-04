import Foundation
import UIKit

/// Monitors the main runloop for stalls using CFRunLoopObserver
///
/// Uses a heartbeat mechanism to detect when the main thread is blocked.
/// A background timer continuously updates a timestamp on the main thread.
/// If the timestamp isn't updated within the threshold, a stall is detected.
class RunLoopMonitor {
    private let stallThresholdMs: Int
    private let captureStackTraces: Bool
    private let onStallDetected: (FreezeEvent) -> Void

    private var isRunning = false
    private var heartbeatTimer: Timer?
    private var lastHeartbeatTime: UInt64 = 0
    private var monitorQueue: DispatchQueue?
    private let semaphore = DispatchSemaphore(value: 1)

    // Convert milliseconds to nanoseconds
    private var stallThresholdNs: UInt64 {
        return UInt64(stallThresholdMs) * 1_000_000
    }

    init(
        stallThresholdMs: Int,
        captureStackTraces: Bool,
        onStallDetected: @escaping (FreezeEvent) -> Void
    ) {
        self.stallThresholdMs = stallThresholdMs
        self.captureStackTraces = captureStackTraces
        self.onStallDetected = onStallDetected
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Create a dedicated queue for monitoring
        monitorQueue = DispatchQueue(
            label: "com.performance_guard.monitor",
            qos: .utility
        )

        // Start heartbeat on main thread
        DispatchQueue.main.async { [weak self] in
            self?.startHeartbeat()
        }

        // Start monitoring on background queue
        monitorQueue?.async { [weak self] in
            self?.monitorRunLoop()
        }
    }

    func stop() {
        isRunning = false
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        monitorQueue = nil
    }

    private func startHeartbeat() {
        guard isRunning else { return }

        // Update heartbeat time immediately
        lastHeartbeatTime = mach_absolute_time()

        // Create a repeating timer that updates the heartbeat
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.lastHeartbeatTime = mach_absolute_time()
        }

        RunLoop.current.add(heartbeatTimer!, forMode: .common)
    }

    private func monitorRunLoop() {
        var previousHeartbeat: UInt64 = 0

        while isRunning {
            Thread.sleep(forTimeInterval: 0.1) // Check every 100ms

            let currentTime = mach_absolute_time()
            let currentHeartbeat = lastHeartbeatTime

            // Only check if heartbeat has changed since last check
            if currentHeartbeat > 0 && currentHeartbeat == previousHeartbeat {
                // Heartbeat hasn't updated - check if it's a stall
                let timeSinceLastHeartbeat = currentTime - currentHeartbeat

                // Convert to milliseconds
                let timeSinceMs = timeSinceLastHeartbeat / 1_000_000

                if timeSinceMs >= UInt64(stallThresholdMs) {
                    reportStall(durationMs: Int(timeSinceMs))
                }
            }

            previousHeartbeat = currentHeartbeat
        }
    }

    private func reportStall(durationMs: Int) {
        let stackTrace = captureStackTraces ? captureMainThreadStackTrace() : nil

        let event = FreezeEvent(
            freezeDurationMs: durationMs,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            stackTrace: stackTrace,
            threadName: "main",
            platform: "ios",
            type: "runloop_stall",
            metadata: [
                "thresholdMs": stallThresholdMs,
                "appState": getAppState()
            ]
        )

        onStallDetected(event)
    }

    private func captureMainThreadStackTrace() -> String {
        var result = "Main Thread Stack Trace:\n"

        // Get all threads
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let kr = task_threads(
            mach_task_self_,
            &threadList,
            &threadCount
        )

        guard kr == KERN_SUCCESS else {
            return "Failed to get threads"
        }

        defer {
            if let threadList = threadList {
                vm_deallocate(
                    mach_task_self_,
                    vm_address_t(UInt(bitPattern: threadList)),
                    vm_size_t(MemoryLayout<thread_act_t>.size * Int(threadCount))
                )
            }
        }

        // Find main thread and get its stack trace
        let mainThread = mach_thread_self()

        for i in 0..<Int(threadCount) {
            let thread = threadList![i]
            let threadInfo = getThreadInfo(thread: thread)

            if thread == mainThread {
                result += "Thread: \(threadInfo.name) (ID: \(thread))\n"
                result += "State: \(threadInfo.state)\n"
                result += "---\n"
                result += threadInfo.callStack.joined(separator: "\n")
            }

            mach_port_deallocate(mach_task_self_, thread)
        }

        return result
    }

    private func getThreadInfo(thread: thread_t) -> ThreadInfo {
        var threadBasicInfo = thread_basic_info()
        var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

        let kr = withUnsafeMutablePointer(to: &threadBasicInfo) { pointer in
            thread_info(
                thread,
                thread_flavor_t(THREAD_BASIC_INFO),
                thread_info_t(OpaquePointer(pointer)),
                &threadInfoCount
            )
        }

        let isMain = thread == mach_thread_self()
        let name = isMain ? "com.apple.main-thread" : "unknown"

        return ThreadInfo(
            name: name,
            isMainThread: isMain,
            state: getThreadStateString(threadBasicInfo.run_state),
            callStack: [] // Simplified - actual implementation would use backtrace
        )
    }

    private func getThreadStateString(_ state: Int32) -> String {
        switch state {
        case TH_STATE_RUNNING: return "running"
        case TH_STATE_STOPPED: return "stopped"
        case TH_STATE_WAITING: return "waiting"
        case TH_STATE_UNINTERRUPTIBLE: return "uninterruptible"
        case TH_STATE_HALTED: return "halted"
        default: return "unknown (\(state))"
        }
    }

    private func getAppState() -> String {
        // UIApplication.shared must be accessed on the main thread (enforced in Swift 6).
        // This method may be called from a background monitoring queue, so we read
        // the state safely via a synchronous main-thread dispatch.
        if Thread.isMainThread {
            return appStateString(UIApplication.shared.applicationState)
        }
        var state = "unknown"
        DispatchQueue.main.sync {
            state = appStateString(UIApplication.shared.applicationState)
        }
        return state
    }

    private func appStateString(_ applicationState: UIApplication.State) -> String {
        switch applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }
}

struct ThreadInfo {
    let name: String
    let isMainThread: Bool
    let state: String
    let callStack: [String]
}

// Mach kernel constants — must be Int32 to match thread_basic_info.run_state type
private let TH_STATE_RUNNING: Int32 = 1
private let TH_STATE_STOPPED: Int32 = 2
private let TH_STATE_WAITING: Int32 = 3
private let TH_STATE_UNINTERRUPTIBLE: Int32 = 4
private let TH_STATE_HALTED: Int32 = 5
private let THREAD_INFO_MAX: Int32 = 10
