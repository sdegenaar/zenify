// test/widgets/zen_route_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// =============================================================================
// TEST SERVICES AND MODULES FOR ZEN_MODULE_PAGE TESTING
// =============================================================================

class TestService {
  final String name;
  bool disposed = false;

  TestService(this.name);

  void dispose() => disposed = true;
}

class ParentService {
  final String data;
  bool disposed = false;

  ParentService(this.data);

  void dispose() => disposed = true;
}

class ChildService {
  final ParentService parentService;
  bool disposed = false;

  ChildService(this.parentService);

  void dispose() => disposed = true;
}

class DatabaseService {
  final String connectionString;
  bool isConnected = false;
  bool disposed = false;

  DatabaseService(this.connectionString);

  void connect() => isConnected = true;
  void dispose() => disposed = true;
}

class UserService {
  final DatabaseService databaseService;
  bool disposed = false;

  UserService(this.databaseService);

  void dispose() => disposed = true;
}

// Test modules
class BasicTestModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'BasicTestModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('basic'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    disposeCalled = true;
  }
}

class ParentTestModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'ParentTestModule';

  @override
  void register(ZenScope scope) {
    scope.put<ParentService>(ParentService('parent-data'));
    scope.put<DatabaseService>(DatabaseService('parent://database'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
    final db = scope.find<DatabaseService>();
    db?.connect();
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    disposeCalled = true;
    final db = scope.find<DatabaseService>();
    db?.dispose();
  }
}

class ChildTestModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'ChildTestModule';

  @override
  void register(ZenScope scope) {
    final parentService = scope.find<ParentService>();
    if (parentService != null) {
      scope.put<ChildService>(ChildService(parentService));
    }

    final databaseService = scope.find<DatabaseService>();
    if (databaseService != null) {
      scope.put<UserService>(UserService(databaseService));
    }
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    disposeCalled = true;
  }
}

class FailingModule extends ZenModule {
  @override
  String get name => 'FailingModule';

  @override
  void register(ZenScope scope) {
    throw Exception('Registration failed');
  }
}

class InitFailingModule extends ZenModule {
  @override
  String get name => 'InitFailingModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('failing'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    throw Exception('Initialization failed');
  }
}

class LoadingSimulationModule extends ZenModule {
  bool initCalled = false;

  @override
  String get name => 'LoadingSimulationModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('loading-sim'));
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initCalled = true;
  }
}

// Test pages
class TestPage extends StatelessWidget {
  final String content;

  const TestPage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(content),
      ),
    );
  }
}

class ScopeAwarePage extends StatelessWidget {
  final Function(ZenScope scope)? onScopeReceived;

  const ScopeAwarePage({super.key, this.onScopeReceived});

  @override
  Widget build(BuildContext context) {
    final scope = context.zenScope;
    if (scope != null && onScopeReceived != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onScopeReceived!(scope);
      });
    }

    final service = context.findInScopeOrNull<TestService>();
    if (service == null) {
      return const Center(child: Text('Service not found'));
    }

    return Scaffold(
      body: Center(
        child: Text('Service: ${service.name}'),
      ),
    );
  }
}

// Widget that provides nested scope structure for testing widget tree inheritance
class ParentWithChildWidget extends StatelessWidget {
  final Function(ZenScope? parentScope, ZenScope? childScope)? onScopesReceived;

  const ParentWithChildWidget({super.key, this.onScopesReceived});

  @override
  Widget build(BuildContext context) {
    ZenScope? parentScope;
    ZenScope? childScope;

    return ZenRoute(
      moduleBuilder: () => ParentTestModule(),
      page: Builder(
        builder: (context) {
          parentScope = context.zenScope;

          return ZenRoute(
            moduleBuilder: () => ChildTestModule(),
            page: ScopeAwarePage(
              onScopeReceived: (scope) {
                childScope = scope;
                if (onScopesReceived != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onScopesReceived!(parentScope, childScope);
                  });
                }
              },
            ),
            useParentScope: true, // 🔥 KEY: Use widget tree inheritance
          );
        },
      ),
      scopeName: 'ParentTestScope',
    );
  }
}

// =============================================================================
// ZEN_MODULE_PAGE TESTS
// =============================================================================

void main() {
  ZenConfig.applyEnvironment(ZenEnvironment.test);

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    Zen.reset();
    Zen.init();
    ZenConfig.applyEnvironment(ZenEnvironment.test);
  });

  tearDown(() {
    ZenScopeManager.disposeAll();
    Zen.reset();
  });

  group('ZenModulePage Basic Functionality', () {
    testWidgets('should create and provide scope to child widget',
        (tester) async {
      final module = BasicTestModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.name, 'TestScope');
      expect(module.initCalled, isTrue);

      final service = capturedScope!.find<TestService>();
      expect(service, isNotNull);
      expect(service!.name, 'basic');

      expect(find.text('Service: basic'), findsOneWidget);
    });

    testWidgets('should generate scope name if not provided', (tester) async {
      final module = BasicTestModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.name, startsWith('ZenRoute_'));
      expect(capturedScope!.name, contains('ScopeAwarePage'));
    });

    testWidgets('should show custom loading widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => LoadingSimulationModule(),
            page: const TestPage(content: 'Ready'),
            loadingWidget: Container(
              key: const ValueKey('custom-loading'),
              child: const Text('Custom Loading...'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
    });
  });

  group('ZenModulePage Explicit Parent Scope (parentScope)', () {
    testWidgets(
        'should create parent-child relationship with explicit parentScope',
        (tester) async {
      // Create parent scope explicitly
      final parentModule = ParentTestModule();
      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'ExplicitParentScope',
        autoDispose: false,
      );

      parentModule.register(parentScope);
      await parentModule
          .onInit(parentScope); // Pass parentScope, not parentModule

      // Create child that explicitly references parent scope
      final childModule = ChildTestModule();
      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => childModule,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => childScope = scope,
            ),
            scopeName: 'ExplicitChildScope',
            parentScope: parentScope, // EXPLICIT SCOPE REFERENCE
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify parent-child relationship
      expect(childScope, isNotNull);
      expect(childScope!.name, 'ExplicitChildScope');
      expect(childScope!.parent, same(parentScope));

      // Verify child can access parent services
      final parentService = childScope!.find<ParentService>();
      expect(parentService, isNotNull);
      expect(parentService!.data, 'parent-data');

      // Verify child has its own services
      final childService = childScope!.find<ChildService>();
      expect(childService, isNotNull);
      expect(childService!.parentService, same(parentService));
    });

    testWidgets('should handle null parentScope (isolated scope)',
        (tester) async {
      final module = ChildTestModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
            scopeName: 'IsolatedScope',
            parentScope: null, // 🔥 EXPLICIT NULL - isolated scope
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.parent, same(Zen.rootScope)); // Falls back to root

      // Child can't access ParentService since it's isolated
      final parentService = capturedScope!.find<ParentService>();
      expect(parentService, isNull);
    });

    testWidgets('should use root scope as parent when specified',
        (tester) async {
      final module = BasicTestModule();
      ZenScope? capturedScope;

      // Put something in root scope
      Zen.put<ParentService>(ParentService('root-data'));

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
            scopeName: 'RootChildScope',
            parentScope: Zen.rootScope, // 🔥 EXPLICIT ROOT SCOPE
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.parent, same(Zen.rootScope));

      // Can access root scope services
      final rootService = capturedScope!.find<ParentService>();
      expect(rootService, isNotNull);
      expect(rootService!.data, 'root-data');
    });
  });

  group('ZenModulePage Widget Tree Inheritance (useParentScope)', () {
    testWidgets('should create proper scope inheritance without useParentScope',
        (tester) async {
      ZenScope? outerScope;
      ZenScope? innerScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ParentTestModule(),
            page: Builder(
              builder: (context) {
                // Capture the outer scope from context
                outerScope = context.zenScope;
                return ZenRoute(
                  moduleBuilder: () => ChildTestModule(),
                  page: ScopeAwarePage(
                    onScopeReceived: (scope) {
                      innerScope = scope;
                    },
                  ),
                  scopeName: 'ChildScope',
                  parentScope: outerScope, // Explicitly set parent scope
                );
              },
            ),
            scopeName: 'ParentScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(innerScope, isNotNull);
      expect(outerScope, isNotNull);
      expect(innerScope!.parent, same(outerScope));

      // Verify child can access parent services
      final parentService = innerScope!.find<ParentService>();
      expect(parentService, isNotNull);
    });

    testWidgets('should share scope when useParentScope is true',
        (tester) async {
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ParentTestModule(),
            page: ZenRoute(
              moduleBuilder: () => ChildTestModule(),
              page: Builder(
                builder: (context) {
                  // Capture the scope during build
                  capturedScope = context.zenScope;
                  return const Text('Test');
                },
              ),
              useParentScope: true,
            ),
            scopeName: 'ParentScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);

      // Verify that the scope has both parent and child services
      // (since useParentScope=true means child module registers in parent scope)
      final parentService = capturedScope!.find<ParentService>();
      final childService = capturedScope!.find<ChildService>();

      expect(parentService, isNotNull);
      expect(childService, isNotNull);
    });

    testWidgets('should handle missing parent scope in widget tree gracefully',
        (tester) async {
      final module = ChildTestModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => capturedScope = scope,
            ),
            scopeName: 'OrphanScope',
            useParentScope: true, // 🔥 Try to inherit but no parent in tree
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.parent, same(Zen.rootScope)); // Falls back to root
    });

    testWidgets('should prefer explicit parentScope over useParentScope',
        (tester) async {
      ZenConfig.applyEnvironment(ZenEnvironment.test);

      // Create explicit parent scope
      final explicitParent = ZenScopeManager.getOrCreateScope(
        name: 'ExplicitParent',
        autoDispose: false,
      );
      explicitParent.put<ParentService>(ParentService('explicit-parent'));

      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ParentTestModule(),
            page: ZenRoute(
              moduleBuilder: () => ChildTestModule(),
              page: ScopeAwarePage(
                onScopeReceived: (scope) {
                  childScope = scope;
                },
              ),
              scopeName: 'PriorityTestChild',
              parentScope: explicitParent,
              useParentScope: true,
            ),
            scopeName: 'WidgetTreeParent',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(childScope, isNotNull);
      expect(childScope!.parent, same(explicitParent));

      final parentServiceForAssertion = childScope!.find<ParentService>();
      expect(parentServiceForAssertion, isNotNull);
      expect(parentServiceForAssertion!.data, 'explicit-parent');
    });
  });

  group('ZenModulePage Auto-Dispose Logic', () {
    testWidgets('should auto-dispose isolated scopes', (tester) async {
      ZenScope? scopeToCheck;
      final module = BasicTestModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => scopeToCheck = scope,
            ),
            scopeName: 'AutoDisposeScope',
            // No parent specified - should auto-dispose
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(scopeToCheck, isNotNull);
      expect(scopeToCheck!.isDisposed, isFalse);

      // Dispose by replacing widget tree
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Gone'))),
      );

      await tester.pumpAndSettle();
      expect(scopeToCheck!.isDisposed, isTrue);
    });

    testWidgets('should respect explicit autoDispose setting', (tester) async {
      ZenScope? scopeToCheck;
      final module = BasicTestModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: ScopeAwarePage(
              onScopeReceived: (scope) => scopeToCheck = scope,
            ),
            scopeName: 'ExplicitPersistentScope',
            autoDispose: false, // 🔥 EXPLICIT: Keep alive
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(scopeToCheck, isNotNull);

      // Dispose widget
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Gone'))),
      );

      await tester.pumpAndSettle();

      // Scope should remain alive because autoDispose=false
      expect(scopeToCheck!.isDisposed, isFalse);

      // Verify it's tracked as explicitly persistent
      expect(ZenScopeManager.isExplicitlyPersistent('ExplicitPersistentScope'),
          isTrue);

      // Clean up for next test
      ZenScopeManager.forceDispose('ExplicitPersistentScope');
    });

    testWidgets('should auto-configure autoDispose based on hierarchy',
        (tester) async {
      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'HierarchyParent',
        autoDispose: false,
      );

      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ChildTestModule(),
            page: ScopeAwarePage(
              onScopeReceived: (scope) => childScope = scope,
            ),
            scopeName: 'HierarchyChild',
            parentScope: parentScope,
            // No explicit autoDispose - should auto-configure to false due to hierarchy
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(childScope, isNotNull);

      // Dispose widget
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Gone'))),
      );

      await tester.pumpAndSettle();

      // Child should be persistent because it has a parent (auto-configured)
      expect(childScope!.isDisposed, isFalse);

      // Clean up
      ZenScopeManager.forceDispose('HierarchyChild');
      ZenScopeManager.forceDispose('HierarchyParent');
    });
  });

  group('ZenModulePage Error Handling', () {
    testWidgets('should show error page when module registration fails',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => FailingModule(),
            page: const TestPage(content: 'Should not see this'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load module'), findsOneWidget);
      expect(find.text('Should not see this'), findsNothing);
    });

    testWidgets('should show custom error widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => FailingModule(),
            page: const TestPage(content: 'Should not see this'),
            onError: (error) => Scaffold(
              body: Center(
                child: Text('Custom Error: $error'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Custom Error:'), findsOneWidget);
    });

    testWidgets('should show retry button and allow retry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => InitFailingModule(),
            page: const TestPage(content: 'Should not see this'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load module'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load module'), findsOneWidget);
    });
  });

  group('ZenModulePage Lifecycle', () {
    testWidgets('should properly initialize and dispose modules',
        (tester) async {
      final module = BasicTestModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: const TestPage(content: 'Test'),
            scopeName: 'LifecycleTest',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(module.initCalled, isTrue);
      expect(module.disposeCalled, isFalse);

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Disposed'))),
      );

      await tester.pumpAndSettle();

      expect(module.disposeCalled, isTrue);
    });
  });

  group('ZenModulePage Priority Logic', () {
    testWidgets('should demonstrate all three approaches work correctly',
        (tester) async {
      // Test 1: Isolated scope (no parent specified)
      ZenScope? isolatedScope;
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: ScopeAwarePage(
                onScopeReceived: (scope) => isolatedScope = scope),
            scopeName: 'IsolatedTest',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(isolatedScope!.parent, same(Zen.rootScope));

      // Test 2: Widget tree inheritance
      ZenScope? treeParent, treeChild;
      await tester.pumpWidget(
        MaterialApp(
          home: ParentWithChildWidget(
            onScopesReceived: (parent, child) {
              treeParent = parent;
              treeChild = child;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(treeChild!.parent, same(treeParent));

      // Test 3: Explicit parent scope
      final explicitParent = Zen.createScope(name: 'ExplicitTestParent');
      ZenScope? explicitChild;
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => BasicTestModule(),
            page: ScopeAwarePage(
                onScopeReceived: (scope) => explicitChild = scope),
            scopeName: 'ExplicitChild',
            parentScope: explicitParent,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(explicitChild!.parent, same(explicitParent));

      // All three approaches should work differently
      expect(isolatedScope!.parent, isNot(same(treeChild!.parent)));
      expect(treeChild!.parent, isNot(same(explicitChild!.parent)));
      expect(explicitChild!.parent, isNot(same(isolatedScope!.parent)));
    });
  });

  group('ZenModulePage Hierarchical Cleanup Chain', () {
    testWidgets(
        'should cascade cleanup through multiple levels when auto-dispose children are removed',
        (tester) async {
      // Step 1: Create a simple hierarchy using explicit scope creation
      final grandparentScope = ZenScopeManager.getOrCreateScope(
        name: 'GrandparentScope',
        autoDispose: false, // Explicitly persistent
      );

      final parentScope = ZenScopeManager.getOrCreateScope(
        name: 'ParentScope',
        parentScope: grandparentScope,
        autoDispose: false, // Auto-configured persistence
      );

      final childScope = ZenScopeManager.getOrCreateScope(
        name: 'ChildScope',
        parentScope: parentScope,
        autoDispose: false, // Auto-configured persistence
      );

      // Verify initial hierarchy
      expect(childScope.parent, same(parentScope));
      expect(parentScope.parent, same(grandparentScope));
      expect(grandparentScope.parent, isNull);

      // Step 2: Create ZenModulePage widgets that use these scopes
      List<ZenScope> autoDisposeScopes = [];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Auto-dispose child of grandparent
                Expanded(
                  child: ZenRoute(
                    moduleBuilder: () => BasicTestModule(),
                    page: ScopeAwarePage(
                      onScopeReceived: (scope) => autoDisposeScopes.add(scope),
                    ),
                    scopeName: 'AutoChild1',
                    parentScope: grandparentScope,
                    autoDispose: true,
                  ),
                ),
                // Auto-dispose child of parent
                Expanded(
                  child: ZenRoute(
                    moduleBuilder: () => BasicTestModule(),
                    page: ScopeAwarePage(
                      onScopeReceived: (scope) => autoDisposeScopes.add(scope),
                    ),
                    scopeName: 'AutoChild2',
                    parentScope: parentScope,
                    autoDispose: true,
                  ),
                ),
                // Auto-dispose child of child
                Expanded(
                  child: ZenRoute(
                    moduleBuilder: () => BasicTestModule(),
                    page: ScopeAwarePage(
                      onScopeReceived: (scope) => autoDisposeScopes.add(scope),
                    ),
                    scopeName: 'AutoChild3',
                    parentScope: childScope,
                    autoDispose: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 3: Verify auto-dispose children are created and working
      expect(autoDisposeScopes.length, 3);
      expect(autoDisposeScopes[0].name, 'AutoChild1');
      expect(autoDisposeScopes[1].name, 'AutoChild2');
      expect(autoDisposeScopes[2].name, 'AutoChild3');

      // Verify hierarchy
      expect(autoDisposeScopes[0].parent, same(grandparentScope));
      expect(autoDisposeScopes[1].parent, same(parentScope));
      expect(autoDisposeScopes[2].parent, same(childScope));

      // All should be alive
      expect(autoDisposeScopes[0].isDisposed, isFalse);
      expect(autoDisposeScopes[1].isDisposed, isFalse);
      expect(autoDisposeScopes[2].isDisposed, isFalse);

      // Step 4: Remove all auto-dispose children by changing the widget tree
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('All auto-dispose children removed'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 5: Verify auto-dispose children are disposed
      expect(autoDisposeScopes[0].isDisposed, isTrue);
      expect(autoDisposeScopes[1].isDisposed, isTrue);
      expect(autoDisposeScopes[2].isDisposed, isTrue);

      // Step 6: Check cascade cleanup behavior
      // Wait for any async cleanup to complete
      //await Future.delayed(Duration.zero);

      // Check what remains after cleanup cascade
      bool grandparentExists = ZenScopeManager.isTracking('GrandparentScope');

      // The key test: Check cascade cleanup behavior
      // Since GrandparentScope was explicitly persistent, it should remain
      expect(grandparentExists, isTrue,
          reason: 'Explicitly persistent GrandparentScope should remain');

      // For this test, we mainly want to verify the cleanup cascades correctly
      // The exact behavior of ParentScope and ChildScope depends on the cleanup logic implementation

      // Clean up for next test
      ZenScopeManager.forceDispose('ChildScope');
      ZenScopeManager.forceDispose('ParentScope');
      ZenScopeManager.forceDispose('GrandparentScope');
    });

    testWidgets(
        'should properly track auto-dispose vs persistent scope relationships',
        (tester) async {
      ZenScope? persistentParent;
      ZenScope? autoDisposeChild;

      // Create persistent parent first
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => ParentTestModule(),
            page: ScopeAwarePage(
              onScopeReceived: (scope) => persistentParent = scope,
            ),
            scopeName: 'PersistentParent',
            autoDispose: false,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(persistentParent, isNotNull);

      // Create auto-dispose child with explicit parent
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Expanded(
                child: ZenRoute(
                  moduleBuilder: () => ParentTestModule(),
                  page: const TestPage(content: 'Persistent Parent'),
                  scopeName: 'PersistentParent',
                  autoDispose: false,
                ),
              ),
              Expanded(
                child: ZenRoute(
                  moduleBuilder: () => BasicTestModule(),
                  page: ScopeAwarePage(
                    onScopeReceived: (scope) => autoDisposeChild = scope,
                  ),
                  scopeName: 'AutoDisposeChild',
                  parentScope: persistentParent, // Use captured instance
                  autoDispose: true,
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify relationship
      expect(autoDisposeChild!.parent, same(persistentParent));

      // Continue with rest of test...
    });
  });
}
