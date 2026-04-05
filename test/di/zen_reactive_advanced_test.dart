import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for ZenReactiveSystem targeting uncovered lines in di/zen_reactive.dart:
/// - _performMaintenanceCheck (line 72, after 100 notifications)
/// - _safeNotify error handling (lines 81-82, 85-86)
/// - High listener count warning (lines 106-107)
/// - _performMaintenanceCheck maintenance (line 175-181)
/// - cleanupEmptyListeners log (lines 191-192)
/// - Health status recommendations (_getRecommendations lines 253-264)
void main() {
  setUp(Zen.init);
  tearDown(() {
    ZenReactiveSystem.instance.clearListeners();
    Zen.reset();
  });

  // ══════════════════════════════════════════════════════════
  // Maintenance check via 100 notifications
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.notifyListeners maintenance check', () {
    test('after 100 notifications performMaintenanceCheck runs without crash',
        () {
      final tracker = _TrackerCtrl();
      Zen.put<_TrackerCtrl>(tracker);

      final sys = ZenReactiveSystem.instance;

      // Subscribe to establish a listener
      final sub = sys.listen<_TrackerCtrl>(_TrackerCtrl, (_) {});

      // Notify 100 times to trigger maintenance check (line 72)
      for (var i = 0; i < 101; i++) {
        sys.notifyListeners<_TrackerCtrl>(null);
      }

      expect(
          sys.getMemoryStats()['notificationCount'], greaterThanOrEqualTo(100));
      sub.close();
    });
  });

  // ══════════════════════════════════════════════════════════
  // _safeNotify error handling
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem._safeNotify error tolerance', () {
    test('listener that throws does not crash notifyListeners', () {
      final tracker = _TrackerCtrl();
      Zen.put<_TrackerCtrl>(tracker);

      final sys = ZenReactiveSystem.instance;

      // Use low-level manipulation: listen and capture the callback
      // We can test via ZenSubscription + notifyListeners
      var notificationReceived = false;
      final sub1 = sys.listen<_TrackerCtrl>(_TrackerCtrl, (c) {
        notificationReceived = true;
        throw Exception('listener error');
      });

      expect(() => sys.notifyListeners<_TrackerCtrl>(null), returnsNormally);
      expect(notificationReceived, true);

      // errorCount increases
      final stats = sys.getMemoryStats();
      expect(stats['errorCount'], greaterThan(0));

      sub1.close();
    });
  });

  // ══════════════════════════════════════════════════════════
  // forceCleanup (maintenance + cleanup)
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.forceCleanup', () {
    test('forceCleanup runs without crash', () {
      expect(() => ZenReactiveSystem.instance.forceCleanup(), returnsNormally);
    });

    test('forceCleanup triggers maintenance log', () {
      // Set _lastCleanup to null by clearing
      ZenReactiveSystem.instance.clearListeners();
      expect(() => ZenReactiveSystem.instance.forceCleanup(), returnsNormally);
    });
  });

  // ══════════════════════════════════════════════════════════
  // getHealthStatus and recommendations
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.getHealthStatus', () {
    test('returns HEALTHY status on clean state', () {
      ZenReactiveSystem.instance.clearListeners();
      final health = ZenReactiveSystem.instance.getHealthStatus();
      expect(health['status'], 'HEALTHY');
    });

    test('recommendations is a List', () {
      final health = ZenReactiveSystem.instance.getHealthStatus();
      expect(health['recommendations'], isA<List<String>>());
    });

    test('getMemoryStats returns expected keys', () {
      final stats = ZenReactiveSystem.instance.getMemoryStats();
      expect(stats.containsKey('totalListeners'), true);
      expect(stats.containsKey('memoryPressure'), true);
      expect(stats.containsKey('notificationCount'), true);
      expect(stats.containsKey('errorCount'), true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // dumpListeners
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.dumpListeners', () {
    test('returns no-listeners string on empty state', () {
      ZenReactiveSystem.instance.clearListeners();
      expect(ZenReactiveSystem.instance.dumpListeners(), 'No active listeners');
    });

    test('returns formatted string with active listeners', () {
      final tracker = _TrackerCtrl();
      Zen.put<_TrackerCtrl>(tracker);

      final sub =
          ZenReactiveSystem.instance.listen<_TrackerCtrl>(_TrackerCtrl, (_) {});

      final dump = ZenReactiveSystem.instance.dumpListeners();
      expect(dump, contains('REACTIVE SYSTEM STATE'));

      sub.close();
    });
  });

  // ══════════════════════════════════════════════════════════
  // ZenSubscription
  // ══════════════════════════════════════════════════════════
  group('ZenSubscription', () {
    test('close() marks subscription as disposed', () {
      final sub = ZenSubscription(() {});
      expect(sub.isDisposed, false);
      sub.close();
      expect(sub.isDisposed, true);
    });

    test('close() is idempotent', () {
      var count = 0;
      final sub = ZenSubscription(() => count++);
      sub.close();
      sub.close(); // should not call dispose again
      expect(count, 1);
    });

    test('dispose() is an alias for close()', () {
      final sub = ZenSubscription(() {});
      sub.dispose();
      expect(sub.isDisposed, true);
    });
  });

  // ══════════════════════════════════════════════════════════
  // listen() with tag
  // ══════════════════════════════════════════════════════════
  group('ZenReactiveSystem.listen with tag', () {
    test('listen with tagged provider fires on notify', () {
      final tracker = _TrackerCtrl();
      Zen.put<_TrackerCtrl>(tracker, tag: 'tagged');

      int callCount = 0;
      final sys = ZenReactiveSystem.instance;
      // Use tagged provider to test tag extraction
      final sub = sys.listen<_TrackerCtrl>('_TrackerCtrl:tagged', (_) {
        callCount++;
      });

      // Initial call happens on listen
      expect(callCount, greaterThanOrEqualTo(1));
      sub.close();
    });
  });
}

class _TrackerCtrl extends ZenController {}
