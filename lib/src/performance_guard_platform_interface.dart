import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'models/freeze_event.dart';
import 'method_channel_performance_guard.dart';

/// Platform interface for PerformanceGuard
abstract class PerformanceGuardPlatform extends PlatformInterface {
  PerformanceGuardPlatform() : super(token: _token);

  static final Object _token = Object();

  static PerformanceGuardPlatform _instance = MethodChannelPerformanceGuard();

  /// The default instance of [PerformanceGuardPlatform]
  static PerformanceGuardPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PerformanceGuardPlatform]
  static set instance(PerformanceGuardPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Start monitoring with the given options
  Future<void> start(PerformanceGuardOptions options);

  /// Stop monitoring
  Future<void> stop();

  /// Stream of freeze events from the platform
  Stream<FreezeEvent> get freezeEvents;

  /// Check if monitoring is currently active
  Future<bool> isMonitoring();

  /// Get the current monitoring configuration
  Future<Map<String, dynamic>?> getConfiguration();
}
