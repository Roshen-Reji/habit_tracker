import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Performance statistics for a measured route or UI flow targeting 120fps.
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

/// Debug- and profile-only frame timing logger complying with Section 6 of AGENTS.md.
///
/// Automatically disabled and completely no-op in release mode.
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

  RouteFrameMetrics? getMetrics(String routeName) => _routeMetrics[routeName];

  void reset([String? routeName]) {
    if (routeName != null) {
      _routeMetrics[routeName]?.reset();
    } else {
      for (final m in _routeMetrics.values) {
        m.reset();
      }
    }
  }

  String dumpSummary() {
    final buf = StringBuffer('=== FRAME TIMING SUMMARY (120Hz / 60Hz) ===\n');
    for (final e in _routeMetrics.entries) {
      final m = e.value;
      buf.writeln(
        '[${e.key}] frames: ${m.totalFrames}, '
        'avg: ${m.averageFrameMs.toStringAsFixed(2)}ms, '
        'max: ${m.maxFrameMs.toStringAsFixed(2)}ms, '
        'dropped@120Hz: ${m.dropped120HzFrames}, '
        'dropped@60Hz: ${m.dropped60HzFrames}',
      );
    }
    return buf.toString();
  }
}
