import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import 'package:zenify/debug/zen_system_stats.dart';

class MockNavigationService {
  Map<String, dynamic> getStats() {
    return {
      'currentPath': '/dashboard',
      'totalNavigations': 12,
      'breadcrumbCount': 3,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Core & Debug 100% Coverage Tests', () {
    test('ZenConfig.shouldLogNavigation getter', () {
      ZenConfig.enableNavigationLogging = true;
      ZenConfig.logLevel = ZenLogLevel.info;
      expect(ZenConfig.shouldLogNavigation, isTrue);

      ZenConfig.enableNavigationLogging = false;
      expect(ZenConfig.shouldLogNavigation, isFalse);
      ZenConfig.reset();
    });

    test(
        'ZenWorkers.watch validation for required duration and negative duration',
        () {
      final obs = 0.obs();

      // Missing duration for debounce
      expect(
        () => ZenWorkers.watch<int>(
          obs,
          (v) {},
          type: WorkerType.debounce,
          duration: null,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Missing duration for throttle
      expect(
        () => ZenWorkers.watch<int>(
          obs,
          (v) {},
          type: WorkerType.throttle,
          duration: null,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Missing duration for interval
      expect(
        () => ZenWorkers.watch<int>(
          obs,
          (v) {},
          type: WorkerType.interval,
          duration: null,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative duration
      expect(
        () => ZenWorkers.watch<int>(
          obs,
          (v) {},
          type: WorkerType.ever,
          duration: const Duration(seconds: -1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'ZenSystemStats extracts navigation info when NavigationService is present',
        () {
      final navService = MockNavigationService();
      Zen.put(navService);

      final stats = ZenSystemStats.getSystemStats();
      expect(stats['navigation'], isNotNull);
      final nav = stats['navigation'] as Map<String, dynamic>;
      expect(nav['currentRoute'], '/dashboard');
      expect(nav['navigationCount'], '12');
      expect(nav['breadcrumbCount'], '3');

      Zen.delete<MockNavigationService>();
    });

    test('Zen.init with mutationHandlers registers handlers', () async {
      await Zen.init(
        mutationHandlers: {
          'test_mutation': (args) async => 'done',
        },
        registerDevTools: false,
      );
    });
  });
}
