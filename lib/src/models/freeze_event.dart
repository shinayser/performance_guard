import 'dart:convert';

/// Represents a freeze/ANR event detected by the platform monitors
class FreezeEvent {
  /// Duration of the freeze in milliseconds
  final int freezeDurationMs;

  /// Timestamp when the freeze was detected
  final DateTime timestamp;

  /// Stack trace of the blocked thread (if available)
  final String? stackTrace;

  /// Name of the thread that was blocked
  final String threadName;

  /// Platform where the freeze occurred (android/ios)
  final String platform;

  /// Additional metadata about the freeze
  final Map<String, dynamic>? metadata;

  /// Type of freeze detected (anr, runloop_stall, frame_drop)
  final FreezeType type;

  const FreezeEvent({
    required this.freezeDurationMs,
    required this.timestamp,
    this.stackTrace,
    required this.threadName,
    required this.platform,
    required this.type,
    this.metadata,
  });

  /// Create from platform method channel map
  factory FreezeEvent.fromMap(Map<dynamic, dynamic> map) {
    return FreezeEvent(
      freezeDurationMs: map['freezeDurationMs'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      stackTrace: map['stackTrace'] as String?,
      threadName: map['threadName'] as String,
      platform: map['platform'] as String,
      type: FreezeType.fromString(map['type'] as String),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'freezeDurationMs': freezeDurationMs,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'stackTrace': stackTrace,
      'threadName': threadName,
      'platform': platform,
      'type': type.name,
      'metadata': metadata,
    };
  }

  String toJson() => jsonEncode(toMap());

  @override
  String toString() {
    return 'FreezeEvent(type: ${type.name}, duration: ${freezeDurationMs}ms, '
        'platform: $platform, thread: $threadName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FreezeEvent &&
        other.freezeDurationMs == freezeDurationMs &&
        other.timestamp == timestamp &&
        other.threadName == threadName &&
        other.platform == platform &&
        other.type == type;
  }

  @override
  int get hashCode {
    return Object.hash(
      freezeDurationMs,
      timestamp,
      threadName,
      platform,
      type,
    );
  }
}

/// Types of freeze events that can be detected
enum FreezeType {
  /// Android ANR - main thread blocked
  anr('anr'),

  /// iOS main runloop stall
  runloopStall('runloop_stall'),

  /// UI frame drop detected by Choreographer
  frameDrop('frame_drop'),

  /// Memory pressure causing performance issues
  memoryPressure('memory_pressure'),

  /// Background isolate lag
  isolateLag('isolate_lag');

  final String name;
  const FreezeType(this.name);

  factory FreezeType.fromString(String value) {
    return values.firstWhere(
      (e) => e.name == value,
      orElse: () => anr,
    );
  }
}

/// Configuration options for the performance guard
class PerformanceGuardOptions {
  /// Threshold in milliseconds to consider a freeze (default: 2000ms for ANR)
  final int freezeThresholdMs;

  /// Threshold for frame drop detection (default: 100ms)
  final int frameDropThresholdMs;

  /// Whether to capture stack traces (may have performance impact)
  final bool captureStackTraces;

  /// Sampling interval for monitoring in milliseconds
  final int samplingIntervalMs;

  /// Whether to include app state in reports
  final bool includeAppState;

  /// Minimum freeze duration to report (filters out micro-freezes)
  final int minimumReportDurationMs;

  const PerformanceGuardOptions({
    this.freezeThresholdMs = 2000,
    this.frameDropThresholdMs = 100,
    this.captureStackTraces = true,
    this.samplingIntervalMs = 500,
    this.includeAppState = true,
    this.minimumReportDurationMs = 100,
  });

  Map<String, dynamic> toMap() {
    return {
      'freezeThresholdMs': freezeThresholdMs,
      'frameDropThresholdMs': frameDropThresholdMs,
      'captureStackTraces': captureStackTraces,
      'samplingIntervalMs': samplingIntervalMs,
      'includeAppState': includeAppState,
      'minimumReportDurationMs': minimumReportDurationMs,
    };
  }
}
