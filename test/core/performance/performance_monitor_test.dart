import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/core/performance/performance_monitor.dart';

void main() {
  test('records asynchronous operation duration and timeline label', () async {
    final List<(PerformanceOperation, Duration)> measurements =
        <(PerformanceOperation, Duration)>[];
    final PerformanceMonitor monitor = PerformanceMonitor(
      onMeasurement: (operation, elapsed) {
        measurements.add((operation, elapsed));
      },
    );

    final int result = await monitor.measure(
      PerformanceOperation.imageImport,
      () async {
        await Future<void>.delayed(Duration.zero);
        return 42;
      },
    );

    expect(result, 42);
    expect(measurements, hasLength(1));
    expect(measurements.single.$1, PerformanceOperation.imageImport);
    expect(measurements.single.$2, greaterThanOrEqualTo(Duration.zero));
  });

  test('finishing a startup trace is idempotent', () {
    int measurements = 0;
    final PerformanceMonitor monitor = PerformanceMonitor(
      onMeasurement: (_, _) => measurements++,
    );
    final PerformanceTrace trace = monitor.start(
      PerformanceOperation.appStartup,
    );

    trace.finish();
    trace.finish();

    expect(measurements, 1);
  });

  test('records failed operations without replacing their error', () async {
    final List<PerformanceOperation> operations = <PerformanceOperation>[];
    final PerformanceMonitor monitor = PerformanceMonitor(
      onMeasurement: (operation, _) => operations.add(operation),
    );

    await expectLater(
      monitor.measure<void>(
        PerformanceOperation.vaultUnlock,
        () => Future<void>.error(StateError('failure')),
      ),
      throwsStateError,
    );
    expect(operations, <PerformanceOperation>[
      PerformanceOperation.vaultUnlock,
    ]);
  });
}
