# Performance Guard

A production-grade Flutter plugin for detecting ANRs (App Not Responding), UI freezes, and performance issues in real-time on both Android and iOS.

## Features

- **Cross-platform**: Works on both Android and iOS
- **ANR Detection**: Detects when the main thread is blocked (Android)
- **RunLoop Monitoring**: Monitors main runloop stalls (iOS)
- **Frame Drop Detection**: Detects UI frame drops using Choreographer (Android)
- **Stack Trace Capture**: Optional stack trace capture when freezes occur
- **Configurable Thresholds**: Customizable freeze detection thresholds
- **Stream-based API**: Real-time event streaming to Dart layer
- **Production Ready**: Minimal performance impact, enterprise-grade implementation

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  performance_guard: ^1.0.0
```

## Usage

### Basic Usage

```dart
import 'package:performance_guard/performance_guard.dart';

// Start monitoring
await PerformanceGuard().start(
  const PerformanceGuardOptions(
    freezeThresholdMs: 2000,  // Report freezes > 2 seconds
    captureStackTraces: true,
  ),
  onFreeze: (event) {
    print('Freeze detected: ${event.freezeDurationMs}ms');
    print('Stack trace: ${event.stackTrace}');
  },
);

// Stop monitoring
await PerformanceGuard().stop();
```

### Stream-based Listening

```dart
// Add multiple listeners
final subscription = PerformanceGuard().addListener((event) {
  // Send to crash reporting service
  FirebaseCrashlytics.instance.recordError(
    Exception('UI Freeze'),
    StackTrace.fromString(event.stackTrace ?? ''),
  );
});

// Cancel when done
subscription.cancel();
```

### Configuration Options

```dart
const options = PerformanceGuardOptions(
  freezeThresholdMs: 2000,        // ANR threshold (Android)
  frameDropThresholdMs: 100,       // Frame drop threshold (Android)
  captureStackTraces: true,        // Capture stack traces
  samplingIntervalMs: 500,         // Monitoring interval
  includeAppState: true,           // Include app state in reports
  minimumReportDurationMs: 100,    // Minimum duration to report
);
```

## Platform-Specific Details

### Android

- Uses `Looper` + `Handler` watchdog to detect ANR
- Monitors `Choreographer` for frame drops
- Captures main thread stack traces using `Thread.getStackTrace()`
- Runs monitoring on background coroutines (Kotlin)

### iOS

- Uses `CFRunLoopObserver` to monitor main runloop
- Detects runloop stalls using heartbeat mechanism
- Captures thread stack traces using `task_threads`
- Runs monitoring on dedicated dispatch queue

## Performance Considerations

- **Minimal Overhead**: Monitoring runs on background threads
- **Configurable Sampling**: Adjust sampling interval based on needs
- **Optional Stack Traces**: Disable for minimal performance impact
- **Memory Efficient**: Minimal object allocation in hot paths

## Event Types

| Type | Description | Platform |
|------|-------------|----------|
| `anr` | Main thread blocked | Android |
| `runloopStall` | Main runloop stall | iOS |
| `frameDrop` | UI frame drop detected | Android |

## License

MIT License
