// test/di/zen_service_scope_disposal_test.dart
//
// Tests ZenService scope disposal behavior.
// ZenService extends ZenController — disposal is verified via isDisposed / closeCalled.
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
      Zen.reset();
    });

    test('scope disposal should dispose ZenService instances', () {
      final scope = Zen.createScope(name: 'TestScope');
      final service = TestZenService('scoped');

      scope.put<TestZenService>(service);

      expect(service.isInitialized, true);
      expect(service.initCalled, true);
      expect(service.isDisposed, false);

      scope.dispose();

      expect(service.isDisposed, true);
      expect(service.closeCalled, true);
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

      parentScope.dispose();

      expect(parentService.isDisposed, true);
      expect(childService.isDisposed, true);
      expect(parentService.closeCalled, true);
      expect(childService.closeCalled, true);
    });

    test('tagged ZenServices should be disposed with scope', () {
      final scope = Zen.createScope(name: 'TaggedScope');

      final service1 = TestZenService('service1');
      final service2 = TestZenService('service2');
      final service3 = TestZenService('service3');

      scope.put<TestZenService>(service1, tag: 'first');
      scope.put<TestZenService>(service2, tag: 'second');
      scope.put<TestZenService>(service3); // no tag

      expect(service1.isInitialized, true);
      expect(service2.isInitialized, true);
      expect(service3.isInitialized, true);

      scope.dispose();

      expect(service1.isDisposed, true);
      expect(service2.isDisposed, true);
      expect(service3.isDisposed, true);
      expect(service1.closeCalled, true);
      expect(service2.closeCalled, true);
      expect(service3.closeCalled, true);
    });

    test('lazy ZenService should be disposed when scope is disposed', () {
      final scope = Zen.createScope(name: 'LazyScope');

      scope.putLazy<TestZenService>(() => TestZenService('lazy'));

      final service = scope.find<TestZenService>();
      expect(service, isNotNull);
      expect(service!.name, 'lazy');
      expect(service.isInitialized, true);
      expect(service.initCalled, true);

      scope.dispose();

      expect(service.isDisposed, true);
      expect(service.closeCalled, true);
    });

    test('mixed permanence should respect scope cleanup', () {
      final scope = Zen.createScope(name: 'MixedScope');

      final permanentService = TestZenService('permanent');
      final temporaryService = TestZenService('temporary');

      Zen.put<TestZenService>(permanentService,
          tag: 'permanent', isPermanent: true);
      scope.put<TestZenService>(temporaryService, tag: 'temporary');

      expect(permanentService.isInitialized, true);
      expect(temporaryService.isInitialized, true);

      scope.dispose();

      expect(temporaryService.isDisposed, true);
      expect(temporaryService.closeCalled, true);
      expect(permanentService.isDisposed, false);
      expect(permanentService.closeCalled, false);

      Zen.delete<TestZenService>(tag: 'permanent', force: true);
      expect(permanentService.isDisposed, true);
    });

    test('scope disposal should handle mixed service types correctly', () {
      final scope = Zen.createScope(name: 'MixedTypesScope');

      final zenService = TestZenService('zen');
      final regularService = OtherService('regular');

      scope.put<TestZenService>(zenService);
      scope.put<OtherService>(regularService);

      expect(zenService.isInitialized, true);
      expect(regularService.disposed, false);

      scope.dispose();

      expect(zenService.isDisposed, true);
      expect(zenService.closeCalled, true);
      expect(regularService.disposed, false); // no ZenController lifecycle
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

      for (final service in services) {
        expect(service.isInitialized, true);
      }

      level1.dispose();

      expect(services[0].isDisposed, false); // root
      expect(services[1].isDisposed, true);  // level1
      expect(services[2].isDisposed, true);  // level2
      expect(services[3].isDisposed, true);  // level3

      root.dispose();
      expect(services[0].isDisposed, true);
    });

    test('scope disposal with service initialization errors', () {
      final scope = Zen.createScope(name: 'ErrorScope');

      final problematicService = _ProblematicService();
      final normalService = TestZenService('normal');

      scope.put<_ProblematicService>(problematicService);
      scope.put<TestZenService>(normalService);

      expect(problematicService.isInitialized, true);
      expect(normalService.isInitialized, true);

      expect(() => scope.dispose(), returnsNormally);

      expect(problematicService.isDisposed, true);
      expect(problematicService.closeCalled, true);
      expect(normalService.isDisposed, true);
      expect(normalService.closeCalled, true);
    });

    test('multiple scope disposal should be idempotent', () {
      final scope = Zen.createScope(name: 'IdempotentScope');
      final service = TestZenService('test');

      scope.put<TestZenService>(service);
      expect(service.isInitialized, true);

      scope.dispose();
      expect(service.isDisposed, true);
      expect(service.closeCalled, true);

      service.closeCalled = false;

      expect(() => scope.dispose(), returnsNormally);
      expect(service.closeCalled, false); // onClose shouldn't be called again
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
