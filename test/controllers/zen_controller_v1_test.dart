// test/controllers/zen_controller_v1_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class TestService {
  final value = 'test-service'.obs();
  bool disposed = false;

  void dispose() => disposed = true;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    ZenConfig.applyEnvironment(ZenEnvironment.test);
    ZenConfig.logLevel = ZenLogLevel.none;
  });

  tearDown(() {
    Zen.reset();
  });

  group('Testing Support - V1.0 Feature', () {
    test('testMode().mock() should replace dependencies', () {
      final realService = TestService();
      final mockService = TestService();

      Zen.put<TestService>(realService);
      expect(Zen.find<TestService>(), same(realService));

      Zen.testMode().mock<TestService>(mockService);

      expect(Zen.find<TestService>(), same(mockService));
      expect(Zen.find<TestService>(), isNot(same(realService)));
    });

    test('testMode().isolatedScope() should create isolated scope', () {
      Zen.put<TestService>(TestService());

      final testScope = Zen.testMode().isolatedScope();

      // Isolated scope shouldn't have root dependencies
      expect(testScope.findInThisScope<TestService>(), isNull);

      // Can register test-specific dependencies
      final testService = TestService();
      testScope.put<TestService>(testService);

      expect(testScope.find<TestService>(), same(testService));

      testScope.dispose();
    });

    test('testMode().mockLazy() should register lazy mock', () {
      int factoryCallCount = 0;

      Zen.testMode().mockLazy<TestService>(() {
        factoryCallCount++;
        return TestService();
      });

      expect(factoryCallCount, 0);

      final service = Zen.find<TestService>();
      expect(factoryCallCount, 1);
      expect(service, isNotNull);

      final service2 = Zen.find<TestService>();
      expect(factoryCallCount, 1); // Same instance
      expect(service2, same(service));
    });

    test('testMode() should provide fluent API for multiple mocks', () {
      final service1 = TestService();
      final service2 = TestService();

      Zen.testMode()
          .mock<TestService>(service1, tag: 'first')
          .mock<TestService>(service2, tag: 'second');

      expect(Zen.find<TestService>(tag: 'first'), same(service1));
      expect(Zen.find<TestService>(tag: 'second'), same(service2));
    });
  });
}
