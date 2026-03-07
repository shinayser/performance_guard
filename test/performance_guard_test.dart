import 'package:flutter_test/flutter_test.dart';
import 'package:performance_guard/performance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FreezeEvent', () {
    test('should create from map correctly', () {
      final map = {
        'freezeDurationMs': 2000,
        'timestamp': 1700000000000,
        'stackTrace': 'test stack trace',
        'threadName': 'main',
        'platform': 'android',
        'type': 'anr',
        'metadata': {'key': 'value'},
      };

      final event = FreezeEvent.fromMap(map);

      expect(event.freezeDurationMs, 2000);
      expect(event.threadName, 'main');
      expect(event.platform, 'android');
      expect(event.type, FreezeType.anr);
      expect(event.stackTrace, 'test stack trace');
    });

    test('should convert to map correctly', () {
      final event = FreezeEvent(
        freezeDurationMs: 1500,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        stackTrace: 'trace',
        threadName: 'main',
        platform: 'ios',
        type: FreezeType.runloopStall,
        metadata: {'test': 'data'},
      );

      final map = event.toMap();

      expect(map['freezeDurationMs'], 1500);
      expect(map['threadName'], 'main');
      expect(map['platform'], 'ios');
      expect(map['type'], 'runloop_stall');
    });

    test('should handle null stack trace', () {
      final map = {
        'freezeDurationMs': 1000,
        'timestamp': 1700000000000,
        'stackTrace': null,
        'threadName': 'main',
        'platform': 'android',
        'type': 'frame_drop',
      };

      final event = FreezeEvent.fromMap(map);

      expect(event.stackTrace, isNull);
      expect(event.type, FreezeType.frameDrop);
    });

    test('should support equality comparison', () {
      final event1 = FreezeEvent(
        freezeDurationMs: 2000,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        threadName: 'main',
        platform: 'android',
        type: FreezeType.anr,
      );

      final event2 = FreezeEvent(
        freezeDurationMs: 2000,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        threadName: 'main',
        platform: 'android',
        type: FreezeType.anr,
      );

      expect(event1, equals(event2));
    });
  });

  group('PerformanceGuardOptions', () {
    test('should have default values', () {
      const options = PerformanceGuardOptions();

      expect(options.freezeThresholdMs, 2000);
      expect(options.frameDropThresholdMs, 100);
      expect(options.captureStackTraces, true);
      expect(options.samplingIntervalMs, 500);
      expect(options.includeAppState, true);
      expect(options.minimumReportDurationMs, 100);
    });

    test('should convert to map correctly', () {
      const options = PerformanceGuardOptions(
        freezeThresholdMs: 3000,
        captureStackTraces: false,
      );

      final map = options.toMap();

      expect(map['freezeThresholdMs'], 3000);
      expect(map['captureStackTraces'], false);
    });
  });

  group('FreezeType', () {
    test('should parse from string correctly', () {
      expect(FreezeType.fromString('anr'), FreezeType.anr);
      expect(FreezeType.fromString('runloop_stall'), FreezeType.runloopStall);
      expect(FreezeType.fromString('frame_drop'), FreezeType.frameDrop);
      expect(FreezeType.fromString('memory_pressure'), FreezeType.memoryPressure);
      expect(FreezeType.fromString('isolate_lag'), FreezeType.isolateLag);
    });

    test('should default to anr for unknown strings', () {
      expect(FreezeType.fromString('unknown'), FreezeType.anr);
    });

    test('should have correct names', () {
      expect(FreezeType.anr.name, 'anr');
      expect(FreezeType.runloopStall.name, 'runloop_stall');
      expect(FreezeType.frameDrop.name, 'frame_drop');
    });
  });
}
