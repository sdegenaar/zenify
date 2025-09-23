// test/controllers/zen_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class TestService extends ZenService {
  bool initCalled = false;
  bool closeCalled = false;
  String? initData;

  @override
  void onInit() {
    super.onInit();
    initCalled = true;
    initData = 'initialized';
  }

  @override
  void onClose() {
    closeCalled = true;
    super.onClose();
  }
}

class TestController extends ZenController {
  final value = 'controller'.obs();
}

void main() {
  group('ZenService', () {
    setUp(() {
      ZenConfig.enableDebugLogs = false; // Reduce test noise
    });

    tearDown(() {
      ZenService.disposeAllServices();
      Zen.reset();
    });

    group('Basic Functionality', () {
      test('should call onInit when ensureInitialized is called', () {
        final service = TestService();
        expect(service.initCalled, false);
        expect(service.isInitialized, false);

        service.ensureInitialized();

        expect(service.initCalled, true);
        expect(service.isInitialized, true);
        expect(service.initData, 'initialized');
      });

      test('should not call onInit multiple times', () {
        final service = TestService();
        service.ensureInitialized();
        service.initData = 'modified';

        service.ensureInitialized(); // Call again

        expect(service.initData, 'modified'); // Should not reset
      });

      test('re-entrant ensureInitialized is safe', () {
        final reentrant = _ReentrantInitService();
        reentrant.ensureInitialized();
        expect(reentrant.initCount, 1);
        expect(reentrant.isInitializing, false);
        expect(reentrant.isInitialized, true);
      });

      test('should track active services', () {
        expect(ZenService.activeServiceCount, 0);

        final service1 = TestService();
        expect(ZenService.activeServiceCount, 1);

        final service2 = TestService();
        expect(ZenService.activeServiceCount, 2);

        service1.dispose();
        expect(ZenService.activeServiceCount, 1);

        service2.dispose();
        expect(ZenService.activeServiceCount, 0);
      });

      test('should prevent double disposal', () {
        final service = TestService();

        service.dispose();
        expect(service.closeCalled, true);
        expect(service.isDisposed, true);

        service.closeCalled = false; // Reset flag
        service.dispose(); // Call again

        expect(service.closeCalled, false); // Should not call onClose again
      });

      test('should dispose all services', () {
        final service1 = TestService();
        final service2 = TestService();

        expect(ZenService.activeServiceCount, 2);

        ZenService.disposeAllServices();

        expect(ZenService.activeServiceCount, 0);
        expect(service1.isDisposed, true);
        expect(service2.isDisposed, true);
      });
    });

    group('Integration with Zen.put()', () {
      test('ZenService should default to permanent=true', () {
        final service = TestService();

        // Should not throw and should be permanent
        Zen.put<TestService>(service);

        expect(service.isInitialized, true);
        expect(Zen.exists<TestService>(), true);
      });

      test('ZenService should be initialized immediately on registration', () {
        final service = TestService();
        expect(service.initCalled, false);

        Zen.put<TestService>(service);

        expect(service.initCalled, true);
        expect(service.isInitialized, true);
      });

      test('ZenService permanent can be overridden', () {
        final service = TestService();

        // Explicitly set to non-permanent (unusual but should work)
        Zen.put<TestService>(service, isPermanent: false);

        expect(service.isInitialized, true);
        expect(Zen.exists<TestService>(), true);
      });

      test('ZenController should still default to permanent=false', () {
        final controller = TestController();

        Zen.put<TestController>(controller);

        expect(Zen.exists<TestController>(), true);
        // Note: We can't easily test the permanent flag directly,
        // but we can verify the controller was registered
      });
    });

    group('Integration with Zen.putLazy()', () {
      test('ZenService factory should default to permanent=true', () {
        Zen.putLazy<TestService>(() => TestService());

        // Factory is registered immediately, so exists() returns true
        expect(Zen.exists<TestService>(), true);

        final service = Zen.find<TestService>();
        expect(service.isInitialized, true);
        expect(service.initCalled, true);
      });

      test('ZenController factory should default to permanent=false', () {
        Zen.putLazy<TestController>(() => TestController());

        final controller = Zen.find<TestController>();
        expect(controller.value.value, 'controller');
      });
    });

    group('Edge Cases', () {
      test('should handle exception in onInit gracefully', () {
        final service = _BadInitService();

        expect(() => service.ensureInitialized(), throwsException);
        expect(service.isInitialized, false); // Should remain false
        expect(service.isInitializing, false);
      });

      test('should handle exception in onClose gracefully', () {
        final service = _BadCloseService();
        service.ensureInitialized();

        // Should not throw, just log error
        expect(() => service.dispose(), returnsNormally);
        expect(service.isDisposed, true);
      });

      test('should handle mixed service and controller registration', () {
        final service = TestService();
        final controller = TestController();

        Zen.put<TestService>(service);
        Zen.put<TestController>(controller);

        expect(service.isInitialized, true);
        expect(Zen.exists<TestService>(), true);
        expect(Zen.exists<TestController>(), true);
      });
    });
  });
}

class _BadInitService extends ZenService {
  @override
  void onInit() {
    super.onInit();
    throw Exception('Init failed');
  }
}

class _BadCloseService extends ZenService {
  @override
  void onClose() {
    super.onClose();
    throw Exception('Close failed');
  }
}

class _ReentrantInitService extends ZenService {
  int initCount = 0;

  @override
  void onInit() {
    initCount++;
    // simulate nested ensureInitialized() call from within onInit
    ensureInitialized();
    super.onInit();
  }
}
