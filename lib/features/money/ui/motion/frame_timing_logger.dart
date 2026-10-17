import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Performance statistics for a measured route or UI flow.
class RouteFrameMetrics {
  final String routeName;
  int totalFrames = 0;
  int dropped60HzFrames = 0; // frames taking > 16.66ms
  int dropped120HzFrames = 0; // frames taking > 8.33ms
  int maxFrameMicroseconds = 0;
  int totalFrameMicroseconds = 0;

  RouteFrameMetrics(this.routeName);

  double get averageFrameMs =>
      totalFrames == 0 ? 0.0 : (totalFrameMicroseconds / totalFrames) / 1000.0;
  double get maxFrameMs => maxFrameMicroseconds / 1000.0;

  void recordTiming(FrameTiming timing) {
    totalFrames++;
    final spanMicros = timing.totalSpan.inMicroseconds;
    totalFrameMicroseconds += spanMicros;
    if (spanMicros > maxFrameMicroseconds) {
      maxFrameMicroseconds = spanMicros;
    }
    if (spanMicros > 8333) {
      dropped120HzFrames++;
    }
    if (spanMicros > 16666) {
      dropped60HzFrames++;
    }
  }

  void reset() {
    totalFrames = 0;
    dropped60HzFrames = 0;
    dropped120HzFrames = 0;
    maxFrameMicroseconds = 0;
    totalFrameMicroseconds = 0;
  }
}

/// Debug- and profile-only frame timing logger complying with Section 7 Rule 11.
///
/// Automatically disabled and completely compiled away/no-op in release mode.
class FrameTimingLogger {
  static final FrameTimingLogger _instance = FrameTimingLogger._internal();
  factory FrameTimingLogger() => _instance;
  FrameTimingLogger._internal();

  final Map<String, RouteFrameMetrics> _routeMetrics = {};
  String? _activeRoute;
  bool _installed = false;

  /// Whether timing callbacks should be tracked (only debug & profile).
  static bool get isSupported => kDebugMode || kProfileMode;

  /// Starts tracking frames under [routeName].
  void startTracking(String routeName) {
    if (!isSupported) return;
    _activeRoute = routeName;
    _routeMetrics.putIfAbsent(routeName, () => RouteFrameMetrics(routeName));

    if (!_installed) {
      _installed = true;
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    }
  }

  /// Stops tracking the current route.
  void stopTracking() {
    if (!isSupported) return;
    _activeRoute = null;
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (_activeRoute == null) return;
    final metrics = _routeMetrics[_activeRoute!];
    if (metrics == null) return;

    for (final timing in timings) {
      metrics.recordTiming(timing);
    }
  }

  /// Retrieves current frame metrics for a route.
  RouteFrameMetrics? getMetrics(String routeName) => _routeMetrics[routeName];

  /// Resets metrics for all or a specific route.
  void reset([String? routeName]) {
    if (routeName != null) {
      _routeMetrics[routeName]?.reset();
    } else {
      for (final m in _routeMetrics.values) {
        m.reset();
      }
    }
  }

  /// Dumps summary string for diagnostics.
  String dumpSummary() {
    if (!isSupported) return 'Frame timing not supported in release mode.';
    final buffer = StringBuffer('=== Money v2 Frame Timing Summary ===\n');
    for (final entry in _routeMetrics.entries) {
      final m = entry.value;
      buffer.writeln(
        'Route: ${entry.key} | Total: ${m.totalFrames} | '
        'Avg: ${m.averageFrameMs.toStringAsFixed(2)}ms | '
        'Max: ${m.maxFrameMs.toStringAsFixed(2)}ms | '
        '>16.6ms (60Hz drop): ${m.dropped60HzFrames} | '
        '>8.3ms (120Hz drop): ${m.dropped120HzFrames}',
      );
    }
    return buffer.toString();
  }
}
