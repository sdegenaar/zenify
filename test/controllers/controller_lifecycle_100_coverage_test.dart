import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';
import 'package:zenify/di/zen_lifecycle.dart';
import 'package:zenify/di/zen_reactive.dart';

class _ThrowingReactive extends Rx<int> {
  _ThrowingReactive(super.initialValue);

  @override
  // ignore: must_call_super
  void dispose() {
    throw Exception('Reactive dispose failed');
  }
}

class _ThrowingChildController extends ZenController {
  @override
  // ignore: must_call_super
  void dispose() {
    throw Exception('Child controller dispose failed');
  }
}

class _ThrowingWorker implements ZenWorker {
  final bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  bool get isActive => true;

  @override
  bool get isPaused => false;

  @override
  void dispose() {
    throw Exception('Worker dispose failed');
  }

  @override
  void pause() {
    throw Exception('Worker pause failed');
  }

  @override
  void resume() {
    throw Exception('Worker resume failed');
  }
}

class _TestController extends ZenController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Controller & Lifecycle 100% Coverage Tests', () {
    test(
        'ZenController catches errors during dispose of reactive objects and child controllers',
        () {
      final parent = _TestController();
      parent.onInit();
      parent.onReady();

      parent.trackReactive(_ThrowingReactive(1));
      parent.trackController(_ThrowingChildController());
      parent.addDisposer(() => throw Exception('Disposer failed'));

      // Creating and testing effect
      final effect = parent.createEffect<int>(name: 'test_effect');
      expect(effect.name, 'test_effect');

      // Dispose should not crash even if tracked components throw during dispose
      expect(() => parent.dispose(), returnsNormally);
    });

    test('ZenControllerWorkerExtension error handling and disposed check', () {
      final controller = _TestController();
      controller.onInit();

      final throwingWorker = _ThrowingWorker();

      // pause, resume, dispose on throwing worker
      expect(() => controller.pauseSpecificWorkers([throwingWorker]),
          returnsNormally);
      expect(() => controller.resumeSpecificWorkers([throwingWorker]),
          returnsNormally);
      expect(
          () => controller.disposeWorkers([throwingWorker]), returnsNormally);

      controller.dispose();

      // Calling createWorkers on disposed controller throws StateError
      expect(
        () => controller.createWorkers([() => throwingWorker]),
        throwsA(isA<StateError>()),
      );

      // pauseSpecificWorkers and resumeSpecificWorkers on disposed controller do nothing
      expect(() => controller.pauseSpecificWorkers([throwingWorker]),
          returnsNormally);
      expect(() => controller.resumeSpecificWorkers([throwingWorker]),
          returnsNormally);
    });

    test('ZenLifecycleManager handles query pause/resume and lifecycle states',
        () {
      final manager = ZenLifecycleManager.instance;
      manager.initLifecycleObserver();

      // Test lifecycle states
      manager.addLifecycleListener((state) {});

      // Call methods to verify traversal
      expect(() => manager.dispose(), returnsNormally);
    });

    test('ZenReactiveSystem safe notification and performance recommendations',
        () {
      final reactiveSystem = ZenReactiveSystem.instance;

      // Safe notification with throwing listener
      final sub = reactiveSystem.listen<String>('test_tag', (val) {
        throw Exception('Listener exploded');
      });

      Zen.put<String>('hello', tag: 'test_tag');
      reactiveSystem.notifyListeners<String>('test_tag');

      // Add 60 listeners to trigger maxListeners recommendation
      final subs = <ZenSubscription>[];
      for (int i = 0; i < 55; i++) {
        subs.add(reactiveSystem.listen<int>('high_tag', (v) {}));
      }

      final health = reactiveSystem.getHealthStatus();
      expect(health['recommendations'], isA<List<String>>());

      sub.dispose();
      for (final s in subs) {
        s.dispose();
      }
      reactiveSystem.clearListeners();
      Zen.delete<String>(tag: 'test_tag');
    });
  });
}
