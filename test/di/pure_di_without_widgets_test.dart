// test/di/pure_di_without_widgets_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests that verify Zenify's DI works without WidgetsBinding initialized.
/// This is critical for pure unit tests that don't need Flutter's widget framework.
///
/// Before fix (1.3.4): These tests would fail with "Binding has not yet been initialized"
/// After fix (1.3.5): These tests pass with regular test() instead of testWidgets()

class TestService extends ZenService {
  final name = 'TestService'.obs();

  @override
  void onInit() {
    super.onInit();
    name.value = 'Initialized';
  }
}

class TestController extends ZenController {
  final count = 0.obs();

  void increment() => count.value++;

  @override
  void onInit() {
    super.onInit();
    count.value = 10;
  }

  @override
  void onReady() {
    super.onReady();
    count.value = 20;
  }
}

void main() {
  setUp(() {
    Zen.init();
    ZenConfig.configureTest();
  });

  tearDown(() {
    Zen.testMode().clearQueryCache();
    Zen.reset(); // This used to fail before fix
  });

  group('Pure DI (no WidgetsBinding)', () {
    test('can register and find service without WidgetsBinding', () {
      final service = TestService();
      Zen.put<TestService>(service, isPermanent: true);

      final found = Zen.find<TestService>();
      expect(found, isNotNull);
      expect(found.name.value, 'Initialized');
    });

    test('can register and find controller without WidgetsBinding', () {
      final controller = TestController();
      Zen.put<TestController>(controller);

      final found = Zen.find<TestController>();
      expect(found, isNotNull);
      // onReady should have been called immediately (not after frame)
      expect(found.count.value, 20);
    });

    test('controller lifecycle works without WidgetsBinding', () {
      final controller = TestController();

      expect(controller.count.value, 0);

      Zen.put<TestController>(controller);

      // Both onInit and onReady should have been called immediately
      expect(controller.count.value, 20);
    });

    test('can reset without WidgetsBinding error', () {
      final service = TestService();
      Zen.put<TestService>(service, isPermanent: true);

      // This should not throw "Binding has not yet been initialized"
      expect(() => Zen.reset(), returnsNormally);
    });

    test('reactive values work without WidgetsBinding', () {
      final value = 0.obs();

      expect(value.value, 0);
      value.value = 42;
      expect(value.value, 42);
    });

    test('scope operations work without WidgetsBinding', () {
      final scope = ZenScope(name: 'TestScope');
      scope.put<TestService>(TestService());

      final found = scope.find<TestService>();
      expect(found, isNotNull);

      scope.dispose();
    });
  });

  group('Regression: Issue #xxx (WidgetsBinding in tests)', () {
    test('Zen.reset() in tearDown does not throw', () {
      // Simulate user's flutter_test_config.dart pattern
      Zen.init();
      final service = TestService();
      Zen.put<TestService>(service);

      // This is what failed before fix
      expect(() {
        Zen.testMode().clearQueryCache();
        Zen.reset();
      }, returnsNormally);
    });

    test('controllers initialize properly in test mode', () {
      final controller = TestController();

      // Should not throw about WidgetsBinding
      expect(() => Zen.put<TestController>(controller), returnsNormally);

      // Lifecycle should work
      expect(controller.count.value, 20);
    });
  });
}
