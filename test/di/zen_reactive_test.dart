
// test/di/zen_reactive_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test classes
class ReactiveTestService {
  final String value;
  bool disposed = false;

  ReactiveTestService(this.value);

  void dispose() {
    disposed = true;
  }
}

class CounterService {
  int _count = 0;
  final String? _tag; // Add tag field

  int get count => _count;

  // Add constructor to accept tag
  CounterService([this._tag]);

  void increment() {
    _count++;
    // Notify reactive system with the correct tag
    ZenReactiveSystem.instance.notifyListeners<CounterService>(_tag);
  }

  void reset() {
    _count = 0;
    ZenReactiveSystem.instance.notifyListeners<CounterService>(_tag);
  }
}


class TaggedService {
  final String name;
  String _status = 'idle';

  TaggedService(this.name);

  String get status => _status;

  void updateStatus(String newStatus) {
    _status = newStatus;
    ZenReactiveSystem.instance.notifyListeners<TaggedService>(name);
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ZenReactiveSystem', () {
    late ZenReactiveSystem reactiveSystem;

    setUp(() {
      Zen.reset();
      Zen.init();
      ZenConfig.enableDebugLogs = false;
      reactiveSystem = ZenReactiveSystem.instance;
    });

    tearDown(() {
      reactiveSystem.clearListeners();
      Zen.reset();
    });

    group('Basic Subscription Management', () {
      test('should create and dispose subscriptions correctly', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        bool listenerCalled = false;
        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) => listenerCalled = true,
        );

        // Initial call should trigger listener
        expect(listenerCalled, isTrue);
        expect(subscription.isDisposed, isFalse);

        // Dispose subscription
        subscription.dispose();
        expect(subscription.isDisposed, isTrue);

        // Multiple disposes should be safe
        subscription.dispose();
        expect(subscription.isDisposed, isTrue);
      });

      test('should handle subscription with close() method', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) {},
        );

        subscription.close();
        expect(subscription.isDisposed, isTrue);
      });

      test('should handle multiple subscriptions to same type', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        int callCount1 = 0;
        int callCount2 = 0;

        final sub1 = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) => callCount1++,
        );

        final sub2 = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) => callCount2++,
        );

        // Both should be called initially
        expect(callCount1, 1);
        expect(callCount2, 1);

        // Notify listeners
        reactiveSystem.notifyListeners<ReactiveTestService>(null);

        // Both should be called again
        expect(callCount1, 2);
        expect(callCount2, 2);

        // Dispose one subscription
        sub1.dispose();

        // Notify again
        reactiveSystem.notifyListeners<ReactiveTestService>(null);

        // Only second should be called
        expect(callCount1, 2);
        expect(callCount2, 3);

        sub2.dispose();
      });
    });

    group('Performance Optimizations', () {
      test('should handle zero listeners efficiently', () {
        // No listeners registered
        expect(() => reactiveSystem.notifyListeners<ReactiveTestService>(null),
            returnsNormally);

        final stats = reactiveSystem.getMemoryStats();
        expect(stats['totalListeners'], 0);
      });

      test('should optimize single listener case', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        int callCount = 0;
        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) => callCount++,
        );

        // Initial call
        expect(callCount, 1);

        // Single listener optimization should work
        reactiveSystem.notifyListeners<ReactiveTestService>(null);
        expect(callCount, 2);

        subscription.dispose();
      });

      test('should handle multiple listeners without toList() allocation', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        final callCounts = <int>[];
        final subscriptions = <ZenSubscription>[];

        // Create multiple listeners
        for (int i = 0; i < 5; i++) {
          callCounts.add(0);
          final index = i;
          final sub = reactiveSystem.listen<ReactiveTestService>(
            ReactiveTestService,
                (value) => callCounts[index]++,
          );
          subscriptions.add(sub);
        }

        // All should be called initially
        for (int count in callCounts) {
          expect(count, 1);
        }

        // Notify - should use optimized path
        reactiveSystem.notifyListeners<ReactiveTestService>(null);

        // All should be called again
        for (int count in callCounts) {
          expect(count, 2);
        }

        // Cleanup
        for (final sub in subscriptions) {
          sub.dispose();
        }
      });
    });

    group('Tagged Dependencies', () {
      test('should handle tagged dependencies correctly', () {
        final service1 = TaggedService('service1');
        final service2 = TaggedService('service2');

        Zen.put<TaggedService>(service1, tag: 'first');
        Zen.put<TaggedService>(service2, tag: 'second');

        String? received1, received2;

        final sub1 = reactiveSystem.listen<TaggedService>(
          'TaggedService:first',
              (service) => received1 = service.name,
        );

        final sub2 = reactiveSystem.listen<TaggedService>(
          'TaggedService:second',
              (service) => received2 = service.name,
        );

        // Initial calls
        expect(received1, 'service1');
        expect(received2, 'service2');

        // Update specific tagged service
        service1.updateStatus('active');
        expect(received1, 'service1'); // Should be called again

        // Other service shouldn't be affected by different tag notification
        received1 = null;
        received2 = null;
        reactiveSystem.notifyListeners<TaggedService>('first');

        expect(received1, 'service1');
        expect(received2, isNull);

        sub1.dispose();
        sub2.dispose();
      });

      test('should extract tags correctly from providers', () {
        final service = TaggedService('tagged');
        Zen.put<TaggedService>(service, tag: 'mytag');

        String? received;
        final subscription = reactiveSystem.listen<TaggedService>(
          'TaggedService:mytag',
              (service) => received = service.name,
        );

        expect(received, 'tagged');

        subscription.dispose();
      });
    });

    group('Error Handling', () {
      test('should handle listener errors gracefully', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        bool errorListenerCalled = false;
        bool normalListenerCalled = false;

        // Listener that throws
        final errorSub = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) {
            errorListenerCalled = true;
            throw Exception('Test error');
          },
        );

        // Normal listener
        final normalSub = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) => normalListenerCalled = true,
        );

        // Initial calls
        expect(errorListenerCalled, isTrue);
        expect(normalListenerCalled, isTrue);

        // Reset flags
        errorListenerCalled = false;
        normalListenerCalled = false;

        // Notify - should handle error gracefully
        expect(() => reactiveSystem.notifyListeners<ReactiveTestService>(null),
            returnsNormally);

        // Both should be called despite error
        expect(errorListenerCalled, isTrue);
        expect(normalListenerCalled, isTrue);

        // Error count should be tracked
        final stats = reactiveSystem.getMemoryStats();
        expect(stats['errorCount'], greaterThan(0));

        errorSub.dispose();
        normalSub.dispose();
      });

      test('should handle missing dependencies gracefully', () {
        // Listen to non-existent service
        String? received;
        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) => received = value.value,
        );

        // Should not crash, received should be null
        expect(received, isNull);
        expect(subscription.isDisposed, isFalse);

        subscription.dispose();
      });

      test('should handle errors in initial listener call', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        bool listenerCalled = false;

        // This should not crash despite the error
        expect(() {
          reactiveSystem.listen<ReactiveTestService>(
            ReactiveTestService,
                (value) {
              listenerCalled = true;
              throw Exception('Initial call error');
            },
          );
        }, returnsNormally);

        expect(listenerCalled, isTrue);

        final stats = reactiveSystem.getMemoryStats();
        expect(stats['errorCount'], greaterThan(0));
      });
    });

    group('Memory Management', () {
      test('should track memory statistics correctly', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        final subscriptions = <ZenSubscription>[];

        // Create multiple subscriptions
        for (int i = 0; i < 3; i++) {
          final sub = reactiveSystem.listen<ReactiveTestService>(
            ReactiveTestService,
                (value) {},
          );
          subscriptions.add(sub);
        }

        final stats = reactiveSystem.getMemoryStats();
        expect(stats['totalKeys'], 1);
        expect(stats['totalListeners'], 3);
        expect(stats['maxListenersPerKey'], 3);
        expect(stats['emptyKeys'], 0);

        // Dispose all
        for (final sub in subscriptions) {
          sub.dispose();
        }

        // Force cleanup
        reactiveSystem.forceCleanup();

        final cleanStats = reactiveSystem.getMemoryStats();
        expect(cleanStats['totalListeners'], 0);
        expect(cleanStats['totalKeys'], 0);
      });

      test('should handle memory pressure warnings', () {
        final services = <ReactiveTestService>[];
        final subscriptions = <ZenSubscription>[];

        // Create separate services with different tags to avoid hitting per-key limits
        for (int i = 0; i < 60; i++) {
          final service = ReactiveTestService('test$i');
          services.add(service);
          Zen.put<ReactiveTestService>(service, tag: 'service$i');

          final sub = reactiveSystem.listen<ReactiveTestService>(
            'ReactiveTestService:service$i',
                (value) {},
          );
          subscriptions.add(sub);
        }

        final stats = reactiveSystem.getMemoryStats();
        expect(stats['totalListeners'], greaterThan(50));

        // Cleanup
        for (final sub in subscriptions) {
          sub.dispose();
        }
      });

      test('should automatically cleanup empty listener sets', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) {},
        );

        final statsWithListeners = reactiveSystem.getMemoryStats();
        expect(statsWithListeners['totalKeys'], 1);

        // Dispose subscription
        subscription.dispose();

        // Empty sets should be cleaned up automatically
        final statsAfterDispose = reactiveSystem.getMemoryStats();
        expect(statsAfterDispose['totalKeys'], 0);
      });

      test('should provide health status information', () {
        final health = reactiveSystem.getHealthStatus();

        expect(health, containsPair('status', anyOf(['HEALTHY', 'WARNING', 'CRITICAL'])));
        expect(health, containsPair('memoryPressure', anyOf(['LOW', 'MEDIUM', 'HIGH'])));
        expect(health, containsPair('errorRate', isA<String>()));
        expect(health, containsPair('recommendations', isA<List>()));
      });
    });

    group('Performance Metrics', () {
      test('should track notification counts', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) {},
        );

        final initialStats = reactiveSystem.getMemoryStats();
        final initialCount = initialStats['notificationCount'] as int;

        // Trigger notifications
        for (int i = 0; i < 5; i++) {
          reactiveSystem.notifyListeners<ReactiveTestService>(null);
        }

        final finalStats = reactiveSystem.getMemoryStats();
        final finalCount = finalStats['notificationCount'] as int;

        expect(finalCount, initialCount + 5);

        subscription.dispose();
      });

      test('should handle maintenance check intervals', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) {},
        );

        // Trigger enough notifications to hit maintenance threshold
        for (int i = 0; i < 101; i++) {
          reactiveSystem.notifyListeners<ReactiveTestService>(null);
        }

        // Should not throw and should complete maintenance
        expect(() => reactiveSystem.forceCleanup(), returnsNormally);

        subscription.dispose();
      });
    });

    group('Real-world Integration', () {
      test('should work with counter service example', () {
        final counter = CounterService();
        Zen.put<CounterService>(counter);

        int receivedCount = 0;
        final subscription = reactiveSystem.listen<CounterService>(
          CounterService,
              (service) => receivedCount = service.count,
        );

        // Initial value
        expect(receivedCount, 0);

        // Increment
        counter.increment();
        expect(receivedCount, 1);

        // Multiple increments
        counter.increment();
        counter.increment();
        expect(receivedCount, 3);

        // Reset
        counter.reset();
        expect(receivedCount, 0);

        subscription.dispose();
      });


      test('should work with multiple reactive services', () {
        final counter1 = CounterService('counter1'); // Pass tag to constructor
        final counter2 = CounterService('counter2'); // Pass tag to constructor

        Zen.put<CounterService>(counter1, tag: 'counter1');
        Zen.put<CounterService>(counter2, tag: 'counter2');

        int received1 = -1, received2 = -1;

        final sub1 = reactiveSystem.listen<CounterService>(
          'CounterService:counter1',
              (service) => received1 = service.count,
        );

        final sub2 = reactiveSystem.listen<CounterService>(
          'CounterService:counter2',
              (service) => received2 = service.count,
        );

        // Initial values
        expect(received1, 0);
        expect(received2, 0);

        // Update counter1
        counter1.increment();
        expect(received1, 1);
        expect(received2, 0); // Should not change

        // Update counter2
        counter2.increment();
        counter2.increment();
        expect(received1, 1); // Should not change
        expect(received2, 2);

        sub1.dispose();
        sub2.dispose();
      });
    });

    group('Debug and Monitoring', () {
      test('should provide dump listeners functionality', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        // Empty state
        String dump = reactiveSystem.dumpListeners();
        expect(dump, contains('No active listeners'));

        // With listeners
        final subscription = reactiveSystem.listen<ReactiveTestService>(
          ReactiveTestService,
              (value) {},
        );

        dump = reactiveSystem.dumpListeners();
        expect(dump, contains('REACTIVE SYSTEM STATE'));
        expect(dump, contains('ReactiveTestService'));

        subscription.dispose();
      });

      test('should clear all listeners properly', () {
        final service = ReactiveTestService('test');
        Zen.put<ReactiveTestService>(service);

        // Create multiple subscriptions
        final subscriptions = <ZenSubscription>[];
        for (int i = 0; i < 3; i++) {
          final sub = reactiveSystem.listen<ReactiveTestService>(
            ReactiveTestService,
                (value) {},
          );
          subscriptions.add(sub);
        }

        final statsWithListeners = reactiveSystem.getMemoryStats();
        expect(statsWithListeners['totalListeners'], 3);

        // Clear all
        reactiveSystem.clearListeners();

        final statsAfterClear = reactiveSystem.getMemoryStats();
        expect(statsAfterClear['totalListeners'], 0);
        expect(statsAfterClear['notificationCount'], 0);
        expect(statsAfterClear['errorCount'], 0);
      });
    });
  });
}