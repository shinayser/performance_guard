import 'dart:async';
import 'package:flutter/services.dart';
import 'models/freeze_event.dart';
import 'performance_guard_platform_interface.dart';

/// MethodChannel implementation for PerformanceGuard
class MethodChannelPerformanceGuard extends PerformanceGuardPlatform {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.performance_guard/methods');
  static const EventChannel _eventChannel =
      EventChannel('com.example.performance_guard/events');

  Stream<FreezeEvent>? _freezeEventStream;

  @override
  Future<void> start(PerformanceGuardOptions options) async {
    await _methodChannel.invokeMethod<void>('start', options.toMap());
  }

  @override
  Future<void> stop() async {
    await _methodChannel.invokeMethod<void>('stop');
  }

  @override
  Stream<FreezeEvent> get freezeEvents {
    _freezeEventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) => FreezeEvent.fromMap(event as Map<dynamic, dynamic>));
    return _freezeEventStream!;
  }

  @override
  Future<bool> isMonitoring() async {
    final result = await _methodChannel.invokeMethod<bool>('isMonitoring');
    return result ?? false;
  }

  @override
  Future<Map<String, dynamic>?> getConfiguration() async {
    final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>('getConfiguration');
    return result?.cast<String, dynamic>();
  }
}
