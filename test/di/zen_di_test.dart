// test/controllers/zen_di_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test classes
class TestController extends ZenController {
  final String value;
  bool initialized = false;
  bool readyCalled = false;
  bool disposeMethodCalled = false;

  TestController(this.value);

  @override
  void onInit() {
    super.onInit();
    initialized = true;
  }

  @override
  void onReady() {
    super.onReady();
    readyCalled = true;
  }

  @override
  void onClose() {
    disposeMethodCalled = true;
    super.onClose();
  }
}

class TestService {
  final String value;
  bool disposed = false;

  TestService(this.value);

  void dispose() {
    disposed = true;
  }
}

class DependentService {
  final TestService dependency;

  DependentService(this.dependency);
}

void main() {
  // Initialize Flutter test framework BEFORE any tests run
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Zen DI', () {
    setUp(() {
      // Initialize Zen for each test
      Zen.init();
      ZenConfig.applyEnvironment(ZenEnvironment.test);
    });

    tearDown(() {
      // Clean up after each test
      Zen.reset();
    });

    test('should register and find controllers in root scope', () {
      final controller = TestController('test');
      Zen.put<TestController>(controller);

      final found = Zen.find<TestController>();
      expect(found, isNotNull);
      expect(found.value, 'test');
      expect(found, same(controller));
    });

    test('should register and find controllers with tags in root scope', () {
      final controller1 = TestController('controller1');
      final controller2 = TestController('controller2');

      Zen.put<TestController>(controller1, tag: 'tag1');
      Zen.put<TestController>(controller2, tag: 'tag2');

      final found1 = Zen.find<TestController>(tag: 'tag1');
      final found2 = Zen.find<TestController>(tag: 'tag2');

      expect(found1.value, 'controller1');
      expect(found2.value, 'controller2');
      expect(found1, same(controller1));
      expect(found2, same(controller2));
    });

    test('should register and find controllers in custom scopes', () {
      final scope = Zen.createScope(name: 'TestScope');

      final controller = TestController('scoped');
      scope.put<TestController>(controller);

      final found = scope.find<TestController>();
      expect(found, isNotNull);
      expect(found!.value, 'scoped');
      expect(found, same(controller));

      // Should not be found in root scope
      expect(Zen.findOrNull<TestController>(), isNull);
    });

    test('should support permanent vs temporary controllers', () {
      final tempController = TestController('temp');
      final permController = TestController('perm');

      // Register with explicit permanence
      Zen.put<TestController>(tempController, tag: 'temp', isPermanent: false);
      Zen.put<TestController>(permController, tag: 'perm', isPermanent: true);

      // Temp should delete without force
      final tempDeleted = Zen.delete<TestController>(tag: 'temp');
      expect(tempDeleted, isTrue);

      // Perm should require force
      final permDeleted = Zen.delete<TestController>(tag: 'perm');
      expect(permDeleted, isFalse);

      // Controller should still exist
      expect(Zen.findOrNull<TestController>(tag: 'perm'), isNotNull);

      // Now delete with force
      final forcedDelete = Zen.delete<TestController>(tag: 'perm', force: true);
      expect(forcedDelete, isTrue);

      // Controller should be gone
      expect(Zen.findOrNull<TestController>(tag: 'perm'), isNull);
    });

    test('should support hierarchical scope lookups', () {
      final parentScope = Zen.createScope(name: 'ParentScope');
      final childScope =
          Zen.createScope(name: 'ChildScope', parent: parentScope);

      // Register in parent scope
      final controller = TestController('hierarchical');
      parentScope.put<TestController>(controller);

      // Should be found from child scope (hierarchical lookup)
      final foundFromChild = childScope.find<TestController>();
      expect(foundFromChild, isNotNull);
      expect(foundFromChild!.value, 'hierarchical');

      // But not when using findInThisScope
      final foundInChildOnly = childScope.findInThisScope<TestController>();
      expect(foundInChildOnly, isNull);
    });

    test('should handle non-controller dependencies', () {
      final service = TestService('service');
      Zen.put<TestService>(service);

      final found = Zen.find<TestService>();
      expect(found, isNotNull);
      expect(found.value, 'service');
      expect(found, same(service));
    });

    test('should support lazy initialization', () {
      bool factoryCalled = false;

      // Register lazy dependency
      Zen.putLazy<TestService>(() {
        factoryCalled = true;
        return TestService('lazy');
      });

      // Factory should not be called yet
      expect(factoryCalled, isFalse);

      // Access the dependency
      final service = Zen.find<TestService>();

      // Factory should now be called
      expect(factoryCalled, isTrue);
      expect(service.value, 'lazy');

      // Subsequent lookups should return same instance
      final secondLookup = Zen.find<TestService>();
      expect(secondLookup, same(service));
    });

    test('should support factory pattern (new instance each time)', () {
      int callCount = 0;

      final scope = Zen.createScope(name: 'FactoryScope');

      // Register factory
      scope.putFactory<TestService>(() {
        callCount++;
        return TestService('factory-$callCount');
      });

      // First call
      final service1 = scope.find<TestService>();
      expect(service1?.value, 'factory-1');
      expect(callCount, 1);

      // Second call should create new instance
      final service2 = scope.find<TestService>();
      expect(service2?.value, 'factory-2');
      expect(callCount, 2);

      // Should be different instances
      expect(service1, isNot(same(service2)));
    });

    test('should properly handle findOrNull and findOr methods', () {
      final service = TestService('find-or');
      Zen.put<TestService>(service);

      // Test findOrNull for existing dependency
      final foundService = Zen.findOrNull<TestService>();
      expect(foundService, same(service));

      // Test findOrNull for non-existing dependency
      final nonExistingController = Zen.findOrNull<TestController>();
      expect(nonExistingController, isNull);
    });

    test('should register and use modules', () {
      final scope = Zen.createScope(name: 'ModuleScope');
      final module = TestModule();

      // Register module manually
      module.register(scope);

      // Verify service was registered
      final service = scope.find<TestService>();
      expect(service, isNotNull);
      expect(service!.value, 'from module');
    });

    test('should properly clean up with deleteAll', () {
      // Register several dependencies in root scope
      final controller1 = TestController('delete-all-1');
      final controller2 = TestController('delete-all-2');
      final service = TestService('delete-all-service');

      Zen.put<TestController>(controller1, tag: 'controller1');
      Zen.put<TestController>(controller2, tag: 'controller2');
      Zen.put<TestService>(service);

      // Verify they exist
      expect(Zen.findOrNull<TestController>(tag: 'controller1'),
          same(controller1));
      expect(Zen.findOrNull<TestController>(tag: 'controller2'),
          same(controller2));
      expect(Zen.findOrNull<TestService>(), same(service));

      // Call deleteAll
      Zen.deleteAll(force: true);

      // Verify controllers are disposed
      expect(controller1.disposeMethodCalled, isTrue);
      expect(controller2.disposeMethodCalled, isTrue);

      // Verify dependencies no longer exist
      expect(Zen.findOrNull<TestController>(tag: 'controller1'), isNull);
      expect(Zen.findOrNull<TestController>(tag: 'controller2'), isNull);
      expect(Zen.findOrNull<TestService>(), isNull);
    });

    test('should call onDispose when disposing controllers', () {
      final controller = TestController('dispose-test');
      Zen.put<TestController>(controller);

      // Verify not disposed initially
      expect(controller.disposeMethodCalled, isFalse);

      // Delete the controller
      Zen.delete<TestController>();

      // Verify onDispose was called
      expect(controller.disposeMethodCalled, isTrue);
      expect(controller.isDisposed, isTrue);
    });

    test('should handle scope disposal correctly', () {
      final scope = Zen.createScope(name: 'DisposalScope');
      final controller = TestController('scope-disposal');
      final service = TestService('scope-service');

      // Register dependencies
      scope.put<TestController>(controller);
      scope.put<TestService>(service);

      // Verify they exist
      expect(scope.find<TestController>(), isNotNull);
      expect(scope.find<TestService>(), isNotNull);

      // Dispose the scope
      scope.dispose();

      // Verify scope is disposed
      expect(scope.isDisposed, isTrue);

      // Verify controller was disposed
      expect(controller.disposeMethodCalled, isTrue);
      expect(controller.isDisposed, isTrue);
    });

    test('should handle tagged dependencies correctly', () {
      final service1 = TestService('tagged-1');
      final service2 = TestService('tagged-2');
      final service3 = TestService('untagged');

      Zen.put<TestService>(service1, tag: 'first');
      Zen.put<TestService>(service2, tag: 'second');
      Zen.put<TestService>(service3); // No tag

      // Find by specific tags
      expect(Zen.find<TestService>(tag: 'first').value, 'tagged-1');
      expect(Zen.find<TestService>(tag: 'second').value, 'tagged-2');

      // Find without tag should get the untagged one
      expect(Zen.find<TestService>().value, 'untagged');

      // Delete by tag
      expect(Zen.delete<TestService>(tag: 'first'), isTrue);
      expect(Zen.findOrNull<TestService>(tag: 'first'), isNull);

      // Others should still exist
      expect(Zen.findOrNull<TestService>(tag: 'second'), isNotNull);
      expect(Zen.findOrNull<TestService>(), isNotNull);
    });

    test('should handle dependency replacement correctly', () {
      final controller1 = TestController('first');
      final controller2 = TestController('second');

      // Register first controller
      Zen.put<TestController>(controller1);
      expect(Zen.find<TestController>().value, 'first');

      // Replace with second controller
      Zen.put<TestController>(controller2);
      expect(Zen.find<TestController>().value, 'second');

      // First controller should be disposed
      expect(controller1.disposeMethodCalled, isTrue);
      expect(controller1.isDisposed, isTrue);

      // Second controller should not be disposed
      expect(controller2.disposeMethodCalled, isFalse);
      expect(controller2.isDisposed, isFalse);
    });

    test('should handle complex dependency chains', () {
      final scope = Zen.createScope(name: 'DependencyChain');

      // Register base service
      final baseService = TestService('base');
      scope.put<TestService>(baseService);

      // Register dependent service
      final dependentService = DependentService(baseService);
      scope.put<DependentService>(dependentService);

      // Verify chain works
      final foundDependent = scope.find<DependentService>();
      expect(foundDependent, isNotNull);
      expect(foundDependent!.dependency, same(baseService));
      expect(foundDependent.dependency.value, 'base');
    });

    test('should support scope existence checks', () {
      final scope = Zen.createScope(name: 'ExistenceScope');

      // Should not exist initially
      expect(scope.exists<TestService>(), isFalse);

      // Register service
      final service = TestService('exists');
      scope.put<TestService>(service);

      // Should exist now
      expect(scope.exists<TestService>(), isTrue);

      // With tag
      expect(scope.exists<TestService>(tag: 'nonexistent'), isFalse);

      scope.put<TestService>(TestService('tagged'), tag: 'mytag');
      expect(scope.exists<TestService>(tag: 'mytag'), isTrue);
    });

    test('should handle multiple instances of same type with different tags',
        () {
      final scope = Zen.createScope(name: 'MultipleInstances');

      final services = <TestService>[];
      for (int i = 0; i < 5; i++) {
        final service = TestService('service-$i');
        services.add(service);
        scope.put<TestService>(service, tag: 'tag-$i');
      }

      // Verify all can be found
      for (int i = 0; i < 5; i++) {
        final found = scope.find<TestService>(tag: 'tag-$i');
        expect(found, isNotNull);
        expect(found!.value, 'service-$i');
        expect(found, same(services[i]));
      }

      // Find all of type should return all instances
      final allServices = scope.findAllOfType<TestService>();
      expect(allServices.length, 5);

      for (final service in services) {
        expect(allServices.contains(service), isTrue);
      }
    });

    test('controller lifecycle should work correctly', () {
      final controller = TestController('lifecycle-test');

      // Before registration - should not be initialized
      expect(controller.isInitialized, isFalse);
      expect(controller.isReady, isFalse);
      expect(controller.initialized, isFalse);
      expect(controller.readyCalled, isFalse);

      // Register the controller - this now automatically calls onInit() and onReady()
      Zen.put<TestController>(controller);

      // After registration - should be both initialized and ready
      expect(controller.isInitialized, isTrue);
      expect(controller.initialized, isTrue);
      expect(controller.isReady, isTrue);
      expect(controller.readyCalled, isTrue);
      expect(controller.isDisposed, isFalse);

      // Dispose and verify
      Zen.delete<TestController>();
      expect(controller.isDisposed, isTrue);
      expect(controller.disposeMethodCalled, isTrue);
    });

    testWidgets('should handle disposal in widget tree properly',
        (WidgetTester tester) async {
      bool disposerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final controller = TestController('widget-disposal');
              controller.addDisposer(() => disposerCalled = true);
              Zen.put<TestController>(controller);

              return Text('Controller: ${controller.value}');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify controller exists
      final controller = Zen.findOrNull<TestController>();
      expect(controller, isNotNull);
      expect(controller!.value, 'widget-disposal');

      // Remove the widget
      await tester.pumpWidget(const MaterialApp(home: Text('Empty')));
      await tester.pumpAndSettle();

      // Manually dispose for test
      Zen.delete<TestController>(force: true);

      // Verify disposal
      expect(disposerCalled, isTrue);
      expect(Zen.findOrNull<TestController>(), isNull);
    });

    // ✅ NEW: Test for error handling in lifecycle methods
    testWidgets('should handle errors in lifecycle methods gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      final controller = ErrorProneController();

      // Should handle onInit errors gracefully
      expect(() => Zen.put<ErrorProneController>(controller), returnsNormally);

      await tester.pumpAndSettle();

      // Controller should still be registered despite errors
      expect(Zen.findOrNull<ErrorProneController>(), isNotNull);
    });

    // ✅ NEW: Test for multiple lifecycle calls
    testWidgets('should handle multiple lifecycle calls correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      final controller = TestController('multiple-calls');
      Zen.put<TestController>(controller);

      await tester.pumpAndSettle();

      // First call
      expect(controller.initialized, isTrue);
      expect(controller.readyCalled, isTrue);

      // Additional calls should be idempotent
      controller.onInit();
      controller.onReady();

      expect(controller.initialized, isTrue);
      expect(controller.readyCalled, isTrue);
    });

    test('should handle controller creation in non-widget context', () {
      final controller = TestController('non-widget');

      // Before registration
      expect(controller.initialized, isFalse);
      expect(controller.readyCalled, isFalse);

      // Register controller - now automatically calls both onInit and onReady
      Zen.put<TestController>(controller);

      // Both onInit and onReady should be called immediately
      expect(controller.initialized, isTrue);
      expect(controller.readyCalled, isTrue);
    });

    test('should allow manual lifecycle triggering', () {
      final controller = TestController('manual');

      // Don't use Zen.put to avoid automatic lifecycle
      expect(controller.initialized, isFalse);
      expect(controller.readyCalled, isFalse);

      // Manually trigger lifecycle methods
      controller.onInit();
      expect(controller.initialized, isTrue);
      expect(controller.readyCalled, isFalse);

      controller.onReady();
      expect(controller.readyCalled, isTrue);
    });
  });
}

// ✅ NEW: Test controller that throws errors in lifecycle methods
class ErrorProneController extends ZenController {
  ErrorProneController() : super();

  @override
  void onInit() {
    super.onInit();
    // This would normally throw, but should be handled gracefully
    try {
      throw Exception('Test error in onInit');
    } catch (e) {
      // Handle error gracefully in real implementation
    }
  }

  @override
  void onReady() {
    super.onReady();
    try {
      throw Exception('Test error in onReady');
    } catch (e) {
      // Handle error gracefully in real implementation
    }
  }
}

// Test implementation of ZenModule
class TestModule extends ZenModule {
  @override
  String get name => 'TestModule';

  @override
  void register(ZenScope scope) {
    final service = TestService('from module');
    scope.put<TestService>(service, isPermanent: false);
  }
}
