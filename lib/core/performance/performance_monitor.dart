import 'dart:developer';

enum PerformanceOperation {
  appStartup('app.startup'),
  vaultUnlock('vault.unlock'),
  imageImport('import.images'),
  videoImport('import.videos'),
  documentImport('import.documents');

  const PerformanceOperation(this.timelineName);

  final String timelineName;
}

typedef PerformanceMeasurementSink =
    void Function(PerformanceOperation operation, Duration elapsed);

final class PerformanceMonitor {
  const PerformanceMonitor({this.onMeasurement});

  final PerformanceMeasurementSink? onMeasurement;

  PerformanceTrace start(PerformanceOperation operation) {
    return PerformanceTrace._(
      operation: operation,
      onMeasurement: onMeasurement,
    );
  }

  Future<T> measure<T>(
    PerformanceOperation operation,
    Future<T> Function() action,
  ) async {
    final PerformanceTrace trace = start(operation);
    try {
      return await action();
    } finally {
      trace.finish();
    }
  }
}

final class PerformanceTrace {
  PerformanceTrace._({required this.operation, required this.onMeasurement})
    : _timelineTask = TimelineTask()..start(operation.timelineName),
      _stopwatch = Stopwatch()..start();

  final PerformanceOperation operation;
  final PerformanceMeasurementSink? onMeasurement;
  final TimelineTask _timelineTask;
  final Stopwatch _stopwatch;
  bool _finished = false;

  void finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    _stopwatch.stop();
    _timelineTask.finish(
      arguments: <String, Object>{
        'elapsedMicroseconds': _stopwatch.elapsedMicroseconds,
      },
    );
    try {
      onMeasurement?.call(operation, _stopwatch.elapsed);
    } on Object {
      // Performance reporting must never interrupt the measured operation.
    }
  }
}
