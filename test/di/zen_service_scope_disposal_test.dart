// test/di/zen_service_scope_disposal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class TestZenService extends ZenService {
  final String name;
  bool initCalled = false;
  bool closeCalled = false;

  TestZenService(this.name);

  @override
  void onInit() {
    super.onInit();
    initCalled = true;
  }

  @override
  void onClose() {
    closeCalled = true;
    super.onClose();
  }
}

class OtherService {
  final String name;
  bool disposed = false;

  OtherService(this.name);

  void dispose() {
    disposed = true;
  }
}

void main() {
  group('ZenService Scope Disposal', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      Zen.init();
      ZenConfig.applyEnvironment(ZenEnvironment.test);
    });

    tearDown(() {
      ZenService.disposeAllServices();
      Zen.reset();
    });

    test('scope disposal should dispose ZenService instances', () {
      final scope = Zen.createScope(name: 'TestScope');
      final service = TestZenService('scoped');

      scope.put<TestZenService>(service);

      // Service should be initialized
      expect(service.isInitialized, true);
      expect(service.initCalled, true);
      expect(service.isDisposed, false);

      // Dispose scope
      scope.dispose();

      // Service should be disposed
      expect(service.isDisposed, true);
      expect(service.closeCalled, true);
      expect(ZenService.activeServiceCount, 0);
    });

    test('parent scope disposal should cascade to child services', () {
      final parentScope = Zen.createScope(name: 'ParentScope');
      final childScope =
          Zen.createScope(parent: parentScope, name: 'ChildScope');

      final parentService = TestZenService('parent');
      final childService = TestZenService('child');

      parentScope.put<TestZenService>(parentService, tag: 'parent');
      childScope.put<TestZenService>(childService, tag: 'child');

      expect(parentService.isInitialized, true);
      expect(childService.isInitialized, true);
      expect(ZenService.activeServiceCount, 2);

      // Dispose parent - should cascade to child
      parentScope.dispose();

      expect(parentService.isDisposed, true);
      expect(childService.isDisposed, true);
      expect(parentService.closeCalled, true);
      expect(childService.closeCalled, true);
      expect(ZenService.activeServiceCount, 0);
    });

    test('tagged ZenServices should be disposed with scope', () {
      final scope = Zen.createScope(name: 'TaggedScope');

      final service1 = TestZenService('service1');
      final service2 = TestZenService('service2');
      final service3 = TestZenService('service3');

      scope.put<TestZenService>(service1, tag: 'first');
      scope.put<TestZenService>(service2, tag: 'second');
      scope.put<TestZenService>(service3); // no tag

      expect(ZenService.activeServiceCount, 3);
      expect(service1.isInitialized, true);
      expect(service2.isInitialized, true);
      expect(service3.isInitialized, true);

      // Dispose scope
      scope.dispose();

      // All should be disposed
      expect(service1.isDisposed, true);
      expect(service2.isDisposed, true);
      expect(service3.isDisposed, true);
      expect(service1.closeCalled, true);
      expect(service2.closeCalled, true);
      expect(service3.closeCalled, true);
      expect(ZenService.activeServiceCount, 0);
    });

    test('lazy ZenService should be disposed when scope is disposed', () {
      final scope = Zen.createScope(name: 'LazyScope');

      // Register lazy service factory
      scope.putLazy<TestZenService>(() => TestZenService('lazy'));

      // Service should not exist yet
      expect(ZenService.activeServiceCount, 0);

      // Access service to instantiate it
      final service = scope.find<TestZenService>();
      expect(service, isNotNull);
      expect(service!.name, 'lazy');
      expect(service.isInitialized, true);
      expect(service.initCalled, true);
      expect(ZenService.activeServiceCount, 1);

      // Dispose scope
      scope.dispose();

      // Service should be disposed
      expect(service.isDisposed, true);
      expect(service.closeCalled, true);
      expect(ZenService.activeServiceCount, 0);
    });

    test('mixed permanence should respect scope cleanup', () {
      final scope = Zen.createScope(name: 'MixedScope');

      final permanentService = TestZenService('permanent');
      final temporaryService = TestZenService('temporary');

      // Register permanent service globally (not in scope)
      Zen.put<TestZenService>(permanentService,
          tag: 'permanent', isPermanent: true);

      // Register temporary service in scope
      scope.put<TestZenService>(temporaryService, tag: 'temporary');

      expect(ZenService.activeServiceCount, 2);
      expect(permanentService.isInitialized, true);
      expect(temporaryService.isInitialized, true);

      // Dispose scope
      scope.dispose();

      // Only temporary service should be disposed
      expect(temporaryService.isDisposed, true);
      expect(temporaryService.closeCalled, true);

      // Permanent service should still be active
      expect(permanentService.isDisposed, false);
      expect(permanentService.closeCalled, false);
      expect(ZenService.activeServiceCount, 1);

      // Clean up permanent service
      Zen.delete<TestZenService>(tag: 'permanent', force: true);
      expect(permanentService.isDisposed, true);
      expect(ZenService.activeServiceCount, 0);
    });

    test('scope disposal should handle mixed service types correctly', () {
      final scope = Zen.createScope(name: 'MixedTypesScope');

      final zenService = TestZenService('zen');
      final regularService = OtherService('regular');

      scope.put<TestZenService>(zenService);
      scope.put<OtherService>(regularService);

      expect(zenService.isInitialized, true);
      expect(regularService.disposed, false);
      expect(ZenService.activeServiceCount, 1); // Only ZenService tracked

      // Dispose scope
      scope.dispose();

      // ZenService should be disposed automatically
      expect(zenService.isDisposed, true);
      expect(zenService.closeCalled, true);

      // Regular service should still exist but not disposed automatically
      // (depends on scope implementation - this tests current behavior)
      expect(regularService.disposed, false);
      expect(ZenService.activeServiceCount, 0);
    });

    test('deeply nested scope hierarchy disposal', () {
      final root = Zen.createScope(name: 'Root');
      final level1 = Zen.createScope(parent: root, name: 'Level1');
      final level2 = Zen.createScope(parent: level1, name: 'Level2');
      final level3 = Zen.createScope(parent: level2, name: 'Level3');

      final services = <TestZenService>[];
      for (int i = 0; i < 4; i++) {
        final service = TestZenService('service$i');
        services.add(service);
      }

      root.put<TestZenService>(services[0], tag: 'root');
      level1.put<TestZenService>(services[1], tag: 'level1');
      level2.put<TestZenService>(services[2], tag: 'level2');
      level3.put<TestZenService>(services[3], tag: 'level3');

      expect(ZenService.activeServiceCount, 4);
      for (final service in services) {
        expect(service.isInitialized, true);
      }

      // Dispose from level 1 - should cascade down but not affect root
      level1.dispose();

      // Services in level1, level2, level3 should be disposed
      expect(services[0].isDisposed, false); // root
      expect(services[1].isDisposed, true); // level1
      expect(services[2].isDisposed, true); // level2
      expect(services[3].isDisposed, true); // level3

      expect(ZenService.activeServiceCount, 1); // Only root service remains

      // Clean up root
      root.dispose();
      expect(services[0].isDisposed, true);
      expect(ZenService.activeServiceCount, 0);
    });

    test('scope disposal with service initialization errors', () {
      final scope = Zen.createScope(name: 'ErrorScope');

      // Create service that throws during onClose
      final problematicService = _ProblematicService();
      final normalService = TestZenService('normal');

      scope.put<_ProblematicService>(problematicService);
      scope.put<TestZenService>(normalService);

      expect(problematicService.isInitialized, true);
      expect(normalService.isInitialized, true);
      expect(ZenService.activeServiceCount, 2);

      // Dispose scope - should handle error gracefully
      expect(() => scope.dispose(), returnsNormally);

      // Both services should be marked as disposed despite error
      expect(problematicService.isDisposed, true);
      expect(problematicService.closeCalled, true);
      expect(normalService.isDisposed, true);
      expect(normalService.closeCalled, true);
      expect(ZenService.activeServiceCount, 0);
    });

    test('multiple scope disposal should be idempotent', () {
      final scope = Zen.createScope(name: 'IdempotentScope');
      final service = TestZenService('test');

      scope.put<TestZenService>(service);
      expect(service.isInitialized, true);
      expect(ZenService.activeServiceCount, 1);

      // First disposal
      scope.dispose();
      expect(service.isDisposed, true);
      expect(service.closeCalled, true);
      expect(ZenService.activeServiceCount, 0);

      // Reset flag to test idempotency
      service.closeCalled = false;

      // Second disposal should be safe
      expect(() => scope.dispose(), returnsNormally);
      expect(service.closeCalled, false); // onClose shouldn't be called again
      expect(ZenService.activeServiceCount, 0);
    });
  });
}

class _ProblematicService extends ZenService {
  bool closeCalled = false;

  @override
  void onClose() {
    closeCalled = true;
    super.onClose();
    throw Exception('Error during disposal');
  }
}
