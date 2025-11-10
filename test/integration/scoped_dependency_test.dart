// test/integration/scoped_dependency_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Service classes for testing scopes
class CounterService {
  int value = 0;

  void increment() => value++;
  void reset() => value = 0;
}

class ConfigService {
  final String environment;
  final bool isDarkMode;

  ConfigService({required this.environment, this.isDarkMode = false});
}

class ResourceService {
  final String scopeName;
  final Map<String, String> resources = {};

  ResourceService({required this.scopeName});

  void addResource(String key, String value) {
    resources[key] = value;
  }

  String? getResource(String key) => resources[key];
}

// Test controller with scope awareness
class ScopedController extends ZenController {
  final CounterService counterService;
  final ConfigService configService;
  final String scopeName;

  ScopedController({
    required this.counterService,
    required this.configService,
    required this.scopeName,
  });

  void incrementCounter() {
    counterService.increment();
    update();
  }

  int get counterValue => counterService.value;
  String get environment => configService.environment;
  bool get isDarkMode => configService.isDarkMode;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize Zen
    Zen.init();
    ZenConfig.applyEnvironment(ZenEnvironment.test); // Apply test settings
    ZenConfig.logLevel = ZenLogLevel.none; // Override to disable all logs
  });

  tearDown(() {
    // Clean up after each test
    Zen.reset();
  });

  group('Scoped Dependencies', () {
    test('should properly isolate dependencies in different scopes', () {
      // Create two separate scopes
      final scopeA = Zen.createScope(name: "ScopeA");
      final scopeB = Zen.createScope(name: "ScopeB");

      // Register counters in both scopes
      final counterA = CounterService();
      final counterB = CounterService();

      scopeA.put<CounterService>(counterA);
      scopeB.put<CounterService>(counterB);

      // Verify counters are properly isolated
      final foundCounterA = scopeA.find<CounterService>();
      final foundCounterB = scopeB.find<CounterService>();

      expect(foundCounterA, same(counterA));
      expect(foundCounterB, same(counterB));
      expect(foundCounterA, isNot(same(foundCounterB)));

      // Modify counterA and check isolation
      counterA.increment();
      expect(counterA.value, 1);
      expect(counterB.value, 0);

      // Verify they remain isolated when accessed through scope
      expect(scopeA.find<CounterService>()?.value, 1);
      expect(scopeB.find<CounterService>()?.value, 0);

      // Clean up
      scopeA.dispose();
      scopeB.dispose();
    });

    test('should support scope hierarchy with dependency inheritance', () {
      // Create parent scope with a config service
      final parentScope = Zen.createScope(name: "ParentScope");
      parentScope.put<ConfigService>(ConfigService(environment: "production"));

      // Create child scopes
      final childScopeA = Zen.createScope(parent: parentScope, name: "ChildA");
      final childScopeB = Zen.createScope(parent: parentScope, name: "ChildB");

      // Each child scope gets its own counter service
      childScopeA.put<CounterService>(CounterService());
      childScopeB.put<CounterService>(CounterService());

      // Verify both child scopes can access the parent config
      expect(childScopeA.find<ConfigService>()?.environment, "production");
      expect(childScopeB.find<ConfigService>()?.environment, "production");

      // Modify the counter in one child scope
      childScopeA.find<CounterService>()?.increment();

      // Verify changes are isolated to that scope
      expect(childScopeA.find<CounterService>()?.value, 1);
      expect(childScopeB.find<CounterService>()?.value, 0);

      // Clean up
      childScopeA.dispose();
      childScopeB.dispose();
      parentScope.dispose();
    });

    test('should shadow parent dependencies when registered in child scope',
        () {
      // Create parent scope with a config service
      final parentScope = Zen.createScope(name: "ParentScope");
      parentScope.put<ConfigService>(ConfigService(environment: "production"));

      // Create child scope
      final childScope =
          Zen.createScope(parent: parentScope, name: "ChildScope");

      // Child scope has access to parent's config
      expect(childScope.find<ConfigService>()?.environment, "production");

      // Register a different config in child scope
      childScope.put<ConfigService>(
          ConfigService(environment: "development", isDarkMode: true));

      // Child should now use its own config
      expect(childScope.find<ConfigService>()?.environment, "development");
      expect(childScope.find<ConfigService>()?.isDarkMode, true);

      // Parent should still have its original config
      expect(parentScope.find<ConfigService>()?.environment, "production");
      expect(parentScope.find<ConfigService>()?.isDarkMode, false);

      // Clean up
      childScope.dispose();
      parentScope.dispose();
    });

    test('should clean up properly when a scope is disposed', () {
      // Create parent and child scopes
      final parentScope = Zen.createScope(name: "ParentScope");
      final childScope =
          Zen.createScope(parent: parentScope, name: "ChildScope");

      // Register dependencies
      final parentConfig = ConfigService(environment: "production");
      final childCounter = CounterService();

      parentScope.put<ConfigService>(parentConfig);
      childScope.put<CounterService>(childCounter);

      // Verify dependencies are accessible
      expect(childScope.find<ConfigService>(), same(parentConfig));
      expect(childScope.find<CounterService>(), same(childCounter));

      // Dispose the child scope
      childScope.dispose();

      // Create a new child scope with the same name
      final newChildScope =
          Zen.createScope(parent: parentScope, name: "ChildScope");

      // Child dependency should be gone
      expect(newChildScope.findInThisScope<CounterService>(), isNull);

      // Parent dependency should still be accessible
      expect(newChildScope.find<ConfigService>(), same(parentConfig));

      // Dispose the parent scope
      parentScope.dispose();

      // Create a new parent scope
      final newParentScope = Zen.createScope(name: "ParentScope");

      // Parent dependency should be gone
      expect(newParentScope.find<ConfigService>(), isNull);

      // Clean up
      newChildScope.dispose();
      newParentScope.dispose();
    });

    test('should support disposing child scopes when parent is disposed', () {
      // Create a scope hierarchy
      final rootScope = Zen.createScope(name: "RootScope");
      final middleScope =
          Zen.createScope(parent: rootScope, name: "MiddleScope");
      final leafScope = Zen.createScope(parent: middleScope, name: "LeafScope");

      // Register dependencies at each level
      rootScope.put<String>("Root", tag: "level");
      middleScope.put<String>("Middle", tag: "level");
      leafScope.put<String>("Leaf", tag: "level");

      // Verify dependencies
      expect(leafScope.find<String>(tag: "level"), "Leaf");
      expect(middleScope.find<String>(tag: "level"), "Middle");
      expect(rootScope.find<String>(tag: "level"), "Root");

      // Dispose root scope
      rootScope.dispose();

      // Create new scopes
      final newRootScope = Zen.createScope(name: "RootScope");
      final newMiddleScope =
          Zen.createScope(parent: newRootScope, name: "MiddleScope");
      final newLeafScope =
          Zen.createScope(parent: newMiddleScope, name: "LeafScope");

      // All dependencies should be gone
      expect(newLeafScope.find<String>(tag: "level"), isNull);
      expect(newMiddleScope.find<String>(tag: "level"), isNull);
      expect(newRootScope.find<String>(tag: "level"), isNull);

      // Clean up
      newLeafScope.dispose();
      newMiddleScope.dispose();
      newRootScope.dispose();
    });

    test(
        'should register and resolve dependencies with type and tag combinations',
        () {
      final scope = Zen.createScope(name: "TestScope");

      // Register multiple instances of same type with different tags
      scope.put<ConfigService>(
        ConfigService(environment: "production"),
        tag: "prod",
      );

      scope.put<ConfigService>(
        ConfigService(environment: "staging"),
        tag: "staging",
      );

      scope.put<ConfigService>(
        ConfigService(environment: "development"),
        tag: "dev",
      );

      // Find by tag
      expect(scope.find<ConfigService>(tag: "prod")?.environment, "production");
      expect(scope.find<ConfigService>(tag: "staging")?.environment, "staging");
      expect(scope.find<ConfigService>(tag: "dev")?.environment, "development");

      // Default type lookup should fail when multiple tagged instances exist
      expect(scope.findInThisScope<ConfigService>(), isNull);

      // Register an untagged instance
      scope.put<ConfigService>(ConfigService(environment: "default"));

      // Now default type lookup should work
      expect(scope.find<ConfigService>()?.environment, "default");

      // Clean up
      scope.dispose();
    });

    test('should support scoped controllers with dependencies', () {
      // Create scopes
      final scope1 = Zen.createScope(name: "Scope1");
      final scope2 = Zen.createScope(name: "Scope2");

      // Register dependencies in each scope
      scope1.put<CounterService>(CounterService());
      scope1.put<ConfigService>(ConfigService(environment: "scope1"));

      scope2.put<CounterService>(CounterService());
      scope2.put<ConfigService>(
          ConfigService(environment: "scope2", isDarkMode: true));

      // Create controllers in each scope
      final controller1 = ScopedController(
        counterService: scope1.find<CounterService>()!,
        configService: scope1.find<ConfigService>()!,
        scopeName: "Scope1",
      );

      final controller2 = ScopedController(
        counterService: scope2.find<CounterService>()!,
        configService: scope2.find<ConfigService>()!,
        scopeName: "Scope2",
      );

      // Register controllers in their respective scopes
      scope1.put<ScopedController>(controller1);
      scope2.put<ScopedController>(controller2);

      // Verify controller dependencies are from the correct scope
      expect(controller1.environment, "scope1");
      expect(controller1.isDarkMode, false);
      expect(controller2.environment, "scope2");
      expect(controller2.isDarkMode, true);

      // Test isolated counters
      controller1.incrementCounter();
      expect(controller1.counterValue, 1);
      expect(controller2.counterValue, 0);

      controller2.incrementCounter();
      controller2.incrementCounter();
      expect(controller1.counterValue, 1);
      expect(controller2.counterValue, 2);

      // Clean up
      scope1.dispose();
      scope2.dispose();
    });

    test('should allow finding all instances of a type across scopes', () {
      // Create a hierarchy of scopes
      final rootScope = Zen.createScope(name: "Root");
      final childA = Zen.createScope(parent: rootScope, name: "ChildA");
      final childB = Zen.createScope(parent: rootScope, name: "ChildB");
      final grandchild = Zen.createScope(parent: childA, name: "Grandchild");

      // Register resource services in each scope
      rootScope.put<ResourceService>(ResourceService(scopeName: "Root"));
      childA.put<ResourceService>(ResourceService(scopeName: "ChildA"));
      childB.put<ResourceService>(ResourceService(scopeName: "ChildB"));
      grandchild.put<ResourceService>(ResourceService(scopeName: "Grandchild"));

      // Add different resources to each service
      rootScope.find<ResourceService>()?.addResource("level", "root");
      childA.find<ResourceService>()?.addResource("level", "childA");
      childB.find<ResourceService>()?.addResource("level", "childB");
      grandchild.find<ResourceService>()?.addResource("level", "grandchild");

      // Find all resource services using the actual API
      final rootServices = rootScope.findAllOfType<ResourceService>();
      final childAServices = childA.findAllOfType<ResourceService>();
      final childBServices = childB.findAllOfType<ResourceService>();
      final grandchildServices = grandchild.findAllOfType<ResourceService>();

      // Verify the correct number of services are found
      expect(rootServices.length, 4); // All services in the tree
      expect(childAServices.length, 2); // ChildA and grandchild
      expect(childBServices.length, 1); // Only ChildB
      expect(grandchildServices.length, 1); // Only grandchild

      // Verify the services have the right resources
      expect(rootServices.any((s) => s.getResource("level") == "root"), true);
      expect(rootServices.any((s) => s.getResource("level") == "childA"), true);
      expect(rootServices.any((s) => s.getResource("level") == "childB"), true);
      expect(rootServices.any((s) => s.getResource("level") == "grandchild"),
          true);

      expect(
          childAServices.any((s) => s.getResource("level") == "childA"), true);
      expect(childAServices.any((s) => s.getResource("level") == "grandchild"),
          true);
      expect(
          childAServices.any((s) => s.getResource("level") == "root"), false);

      expect(grandchildServices.first.getResource("level"), "grandchild");

      // Clean up
      grandchild.dispose();
      childB.dispose();
      childA.dispose();
      rootScope.dispose();
    });

    test('should support lazy and factory dependencies in scopes', () {
      // Create scopes
      final devScope = Zen.createScope(name: "DevScope");
      final prodScope = Zen.createScope(name: "ProdScope");

      // Register lazy dependencies
      devScope.putLazy<ConfigService>(
          () => ConfigService(environment: "development", isDarkMode: true));

      prodScope.putLazy<ConfigService>(
          () => ConfigService(environment: "production", isDarkMode: false));

      // Register factory counter services (new instance each time)
      devScope.putLazy<CounterService>(() => CounterService(), alwaysNew: true);
      prodScope.putLazy<CounterService>(() => CounterService(),
          alwaysNew: true);

      // Access services - lazy should create singleton, factory should create new instances
      final devConfig1 = devScope.find<ConfigService>();
      final devConfig2 = devScope.find<ConfigService>();
      expect(devConfig1, same(devConfig2)); // Same instance from lazy

      final devCounter1 = devScope.find<CounterService>();
      final devCounter2 = devScope.find<CounterService>();
      expect(devCounter1,
          isNot(same(devCounter2))); // Different instances from factory

      // Create controllers using the services
      final devController = ScopedController(
        counterService: devScope.find<CounterService>()!,
        configService: devScope.find<ConfigService>()!,
        scopeName: "DevScope",
      );

      final prodController = ScopedController(
        counterService: prodScope.find<CounterService>()!,
        configService: prodScope.find<ConfigService>()!,
        scopeName: "ProdScope",
      );

      devScope.put<ScopedController>(devController);
      prodScope.put<ScopedController>(prodController);

      // Verify controllers have correct configurations
      expect(devController.environment, "development");
      expect(devController.isDarkMode, true);
      expect(prodController.environment, "production");
      expect(prodController.isDarkMode, false);

      // Test that controllers are isolated
      devController.incrementCounter();
      expect(devController.counterValue, 1);
      expect(prodController.counterValue, 0);

      // Clean up
      devScope.dispose();
      prodScope.dispose();
    });

    test('should support dynamic scope creation and destruction', () {
      // Track scopes with a map
      final Map<String, ZenScope> userScopes = {};

      // Create scopes dynamically
      for (int i = 1; i <= 3; i++) {
        final userId = "user$i";
        final userScope = Zen.createScope(name: "UserScope-$userId");

        // Register user-specific configuration
        userScope.put<ConfigService>(ConfigService(
          environment: "user-instance",
          isDarkMode: i % 2 == 0, // Even users get dark mode
        ));

        // Register user-specific counter
        userScope.put<CounterService>(CounterService());

        // Store scope reference
        userScopes[userId] = userScope;
      }

      // Verify each user has their own isolated dependencies
      expect(userScopes.length, 3);

      // User 1: Light mode
      expect(userScopes["user1"]?.find<ConfigService>()?.isDarkMode, false);

      // User 2: Dark mode
      expect(userScopes["user2"]?.find<ConfigService>()?.isDarkMode, true);

      // User 3: Light mode
      expect(userScopes["user3"]?.find<ConfigService>()?.isDarkMode, false);

      // Increment user 1's counter
      userScopes["user1"]?.find<CounterService>()?.increment();
      userScopes["user1"]?.find<CounterService>()?.increment();

      // Increment user 3's counter once
      userScopes["user3"]?.find<CounterService>()?.increment();

      // Verify counters remain isolated
      expect(userScopes["user1"]?.find<CounterService>()?.value, 2);
      expect(userScopes["user2"]?.find<CounterService>()?.value, 0);
      expect(userScopes["user3"]?.find<CounterService>()?.value, 1);

      // Simulate user 2 logging out - dispose their scope
      userScopes["user2"]?.dispose();
      userScopes.remove("user2");

      // Verify remaining users still have their data
      expect(userScopes["user1"]?.find<CounterService>()?.value, 2);
      expect(userScopes["user3"]?.find<CounterService>()?.value, 1);

      // Create a new scope for user 2 logging back in
      final user2Scope = Zen.createScope(name: "UserScope-user2");
      userScopes["user2"] = user2Scope;

      // Register fresh config and counter
      user2Scope.put<ConfigService>(
          ConfigService(environment: "user-instance", isDarkMode: true));
      user2Scope.put<CounterService>(CounterService());

      // Verify user 2 has a fresh counter
      expect(userScopes["user2"]?.find<CounterService>()?.value, 0);

      // Create a separate scope for global resources
      final globalScope = Zen.createScope(name: "GlobalScope");
      globalScope.put<ResourceService>(ResourceService(scopeName: "Global"));

      // Verify that user scopes don't have access to the global resource
      for (final userScope in userScopes.values) {
        expect(userScope.findInThisScope<ResourceService>(), isNull);
      }

      // And verify the global scope has the expected service
      expect(globalScope.find<ResourceService>()?.scopeName, "Global");

      // Clean up all scopes
      for (final scope in userScopes.values) {
        scope.dispose();
      }
      globalScope.dispose();
    });

    test('should handle complex scope relationships', () {
      // Create a complex scope hierarchy
      final appScope = Zen.createScope(name: "AppScope");
      final featureAScope = Zen.createScope(parent: appScope, name: "FeatureA");
      final featureBScope = Zen.createScope(parent: appScope, name: "FeatureB");
      final sharedScope =
          Zen.createScope(parent: appScope, name: "SharedScope");

      // Create a scope that depends on multiple features
      final integrationScope =
          Zen.createScope(parent: sharedScope, name: "Integration");

      // Register app-level config
      appScope.put<ConfigService>(ConfigService(environment: "app-level"));

      // Register feature-specific services
      featureAScope.put<CounterService>(CounterService(), tag: "featureA");
      featureBScope.put<CounterService>(CounterService(), tag: "featureB");

      // Register shared resources
      sharedScope.put<ResourceService>(ResourceService(scopeName: "Shared"));

      // Test access patterns
      expect(featureAScope.find<ConfigService>()?.environment,
          "app-level"); // Inherited
      expect(featureBScope.find<ConfigService>()?.environment,
          "app-level"); // Inherited
      expect(integrationScope.find<ConfigService>()?.environment,
          "app-level"); // Inherited
      expect(integrationScope.find<ResourceService>()?.scopeName,
          "Shared"); // From parent

      // Test scope isolation
      expect(featureAScope.findInThisScope<CounterService>(tag: "featureB"),
          isNull);
      expect(featureBScope.findInThisScope<CounterService>(tag: "featureA"),
          isNull);

      // Test cross-scope access doesn't work
      expect(featureAScope.find<CounterService>(tag: "featureB"), isNull);
      expect(featureBScope.find<CounterService>(tag: "featureA"), isNull);

      // But each can access their own
      expect(featureAScope.find<CounterService>(tag: "featureA"), isNotNull);
      expect(featureBScope.find<CounterService>(tag: "featureB"), isNotNull);

      // Clean up
      integrationScope.dispose();
      sharedScope.dispose();
      featureBScope.dispose();
      featureAScope.dispose();
      appScope.dispose();
    });

    test('should support tagged dependencies across scope hierarchy', () {
      // Create scope hierarchy
      final rootScope = Zen.createScope(name: "Root");
      final childScope = Zen.createScope(parent: rootScope, name: "Child");

      // Register tagged services at different levels
      rootScope.put<ConfigService>(ConfigService(environment: "root-prod"),
          tag: "prod");
      rootScope.put<ConfigService>(ConfigService(environment: "root-dev"),
          tag: "dev");

      childScope.put<ConfigService>(ConfigService(environment: "child-prod"),
          tag: "prod");
      // Child doesn't have dev config, should inherit from parent

      // Test tag resolution with shadowing
      expect(childScope.find<ConfigService>(tag: "prod")?.environment,
          "child-prod"); // Shadowed
      expect(childScope.find<ConfigService>(tag: "dev")?.environment,
          "root-dev"); // Inherited

      // Test that parent still has original values
      expect(
          rootScope.find<ConfigService>(tag: "prod")?.environment, "root-prod");
      expect(
          rootScope.find<ConfigService>(tag: "dev")?.environment, "root-dev");

      // Register a controller that uses both configs
      final controller = ScopedController(
        counterService: CounterService(), // Local instance
        configService:
            childScope.find<ConfigService>(tag: "prod")!, // Shadowed config
        scopeName: "Child",
      );

      childScope.put<ScopedController>(controller);

      expect(controller.environment, "child-prod");

      // Clean up
      childScope.dispose();
      rootScope.dispose();
    });
  });
}
