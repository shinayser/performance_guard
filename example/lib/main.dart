import 'package:flutter/material.dart';
import 'package:performance_guard/performance_guard.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _performanceGuard = PerformanceGuard();
  final List<FreezeEvent> _events = [];
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startMonitoring() async {
    try {
      await _performanceGuard.start(
        const PerformanceGuardOptions(
          freezeThresholdMs: 1000,  // Report freezes > 1s
          frameDropThresholdMs: 100, // Report frame drops > 100ms
          captureStackTraces: true,
          samplingIntervalMs: 500,
          minimumReportDurationMs: 100,
        ),
        onFreeze: _handleFreezeEvent,
      );

      // Also listen via stream
      _performanceGuard.addListener(_handleFreezeEvent);

      setState(() {
        _isMonitoring = true;
      });
    } catch (e) {
      debugPrint('Failed to start monitoring: $e');
    }
  }

  void _handleFreezeEvent(FreezeEvent event) {
    debugPrint('🚨 FREEZE DETECTED: $event');

    setState(() {
      _events.insert(0, event);
    });

    // Send to crash reporting service
    _reportToCrashlytics(event);
  }

  void _reportToCrashlytics(FreezeEvent event) {
    // Example integration with crash reporting
    // FirebaseCrashlytics.instance.recordError(
    //   Exception('UI Freeze: ${event.freezeDurationMs}ms'),
    //   StackTrace.fromString(event.stackTrace ?? 'No stack trace'),
    //   reason: '${event.type} on ${event.platform}',
    // );
  }

  Future<void> _stopMonitoring() async {
    await _performanceGuard.stop();
    setState(() {
      _isMonitoring = false;
    });
  }

  /// Simulate a UI freeze for testing
  Future<void> _simulateFreeze() async {
    // Block the main thread for 2 seconds
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < 2000) {
      // Busy wait to block UI thread
    }
  }

  @override
  void dispose() {
    _performanceGuard.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Performance Guard Demo'),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isMonitoring ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Controls
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isMonitoring ? null : _startMonitoring,
                    child: const Text('Start'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    child: const Text('Stop'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _simulateFreeze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Simulate Freeze'),
                  ),
                ],
              ),
            ),

            // Events List
            Expanded(
              child: _events.isEmpty
                  ? const Center(child: Text('No freeze events detected'))
                  : ListView.builder(
                      itemCount: _events.length,
                      itemBuilder: (context, index) {
                        final event = _events[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          color: _getEventColor(event.type),
                          child: ListTile(
                            leading: Icon(_getEventIcon(event.type)),
                            title: Text(
                              '${event.type.name.toUpperCase()} - ${event.freezeDurationMs}ms',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Platform: ${event.platform}'),
                                Text('Thread: ${event.threadName}'),
                                Text('Time: ${event.timestamp}'),
                                if (event.stackTrace != null)
                                  Text(
                                    'Stack trace available',
                                    style: TextStyle(
                                      color: Colors.blue[800],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            onTap: () => _showEventDetails(event),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getEventColor(FreezeType type) {
    switch (type) {
      case FreezeType.anr:
        return Colors.red.shade100;
      case FreezeType.runloopStall:
        return Colors.orange.shade100;
      case FreezeType.frameDrop:
        return Colors.yellow.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _getEventIcon(FreezeType type) {
    switch (type) {
      case FreezeType.anr:
        return Icons.block;
      case FreezeType.runloopStall:
        return Icons.timer_off;
      case FreezeType.frameDrop:
        return Icons.animation;
      default:
        return Icons.warning;
    }
  }

  void _showEventDetails(FreezeEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${event.type.name} Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Duration: ${event.freezeDurationMs}ms'),
              Text('Platform: ${event.platform}'),
              Text('Thread: ${event.threadName}'),
              Text('Timestamp: ${event.timestamp}'),
              const SizedBox(height: 16),
              if (event.stackTrace != null) ...[
                const Text(
                  'Stack Trace:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    event.stackTrace!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
