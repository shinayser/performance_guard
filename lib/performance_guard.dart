library performance_guard;

import 'dart:async';
import 'src/models/freeze_event.dart';
import 'src/performance_guard_platform_interface.dart';

export 'src/models/freeze_event.dart';

/// Main API for the PerformanceGuard plugin
///
/// This class provides a singleton interface to start/stop performance monitoring
/// and receive freeze events from the native platforms.
class PerformanceGuard {
  static final PerformanceGuard _instance = PerformanceGuard._internal();

  /// Get the singleton instance
  factory PerformanceGuard() => _instance;

  PerformanceGuard._internal();

  final PerformanceGuardPlatform _platform = PerformanceGuardPlatform.instance;

  StreamSubscription<FreezeEvent>? _subscription;
  final _freezeEventController = StreamController<FreezeEvent>.broadcast();

  /// Stream of freeze events detected by the platform monitors
  Stream<FreezeEvent> get onFreeze => _freezeEventController.stream;

  bool _isMonitoring = false;

  /// Whether performance monitoring is currently active
  bool get isMonitoring => _isMonitoring;

  /// Start performance monitoring with optional configuration
  ///
  /// Example:
  /// ```dart
  /// await PerformanceGuard().start(
  ///   PerformanceGuardOptions(
  ///     freezeThresholdMs: 2000,
  ///     captureStackTraces: true,
  ///   ),
  ///   onFreeze: (event) {
  ///     // Handle freeze event
  ///     print('Freeze detected: ${event.freezeDurationMs}ms');
  ///   },
  /// );
  /// ```
  Future<void> start(
    PerformanceGuardOptions options, {
    void Function(FreezeEvent)? onFreeze,
  }) async {
    if (_isMonitoring) {
      throw StateError('PerformanceGuard is already monitoring');
    }

    await _platform.start(options);

    // Set up event listening
    _subscription = _platform.freezeEvents.listen((event) {
      _freezeEventController.add(event);
      onFreeze?.call(event);
    });

    _isMonitoring = true;
  }

  /// Stop performance monitoring
  ///
  /// This will cancel all active monitoring and close the event stream.
  Future<void> stop() async {
    if (!_isMonitoring) return;

    await _subscription?.cancel();
    _subscription = null;
    await _platform.stop();
    _isMonitoring = false;
  }

  /// Add a custom listener for freeze events
  ///
  /// Returns a subscription that can be cancelled when no longer needed.
  StreamSubscription<FreezeEvent> addListener(
    void Function(FreezeEvent event) listener,
  ) {
    return _freezeEventController.stream.listen(listener);
  }

  /// Dispose the PerformanceGuard instance
  ///
  /// Call this when the app is shutting down or you no longer need monitoring.
  Future<void> dispose() async {
    await stop();
    await _freezeEventController.close();
  }
}
