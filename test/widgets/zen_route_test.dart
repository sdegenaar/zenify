// test/widgets/zen_route_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// =============================================================================
// TEST SERVICES AND MODULES
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

// Test modules
class ParentModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'ParentModule';

  @override
  void register(ZenScope scope) {
    scope.put<ParentService>(ParentService('parent-data'));
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

class ChildModule extends ZenModule {
  bool initCalled = false;
  bool disposeCalled = false;

  @override
  String get name => 'ChildModule';

  @override
  void register(ZenScope scope) {
    final parentService = scope.find<ParentService>()!;
    scope.put<ChildService>(ChildService(parentService));
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

// =============================================================================
// TESTS
// =============================================================================

void main() {
  setUp(() {
    Zen.testMode();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenRoute - Widget Tree-Based Architecture', () {
    testWidgets('creates scope and provides it via InheritedWidget',
        (WidgetTester tester) async {
      final parentModule = ParentModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => parentModule,
            page: Builder(
              builder: (context) {
                capturedScope = context.zenScope;
                return const Scaffold(body: Text('Test'));
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.name, 'TestScope');
      expect(parentModule.initCalled, true);
    });

    testWidgets('automatically discovers parent scope from widget tree',
        (WidgetTester tester) async {
      final parentModule = ParentModule();
      final childModule = ChildModule();

      ZenScope? parentScope;
      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => parentModule,
            page: Builder(
              builder: (context) {
                parentScope = context.zenScope;
                return Navigator(
                  pages: [
                    MaterialPage(
                      child: ZenRoute(
                        moduleBuilder: () => childModule,
                        page: Builder(
                          builder: (context) {
                            childScope = context.zenScope;
                            return const Scaffold(body: Text('Child'));
                          },
                        ),
                        scopeName: 'ChildScope',
                      ),
                    ),
                  ],
                  onDidRemovePage: (page) {},
                );
              },
            ),
            scopeName: 'ParentScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(parentScope, isNotNull);
      expect(childScope, isNotNull);
      expect(childScope!.parent, same(parentScope));
      expect(childScope!.find<ParentService>(), isNotNull);
      expect(childModule.initCalled, true);
    });

    testWidgets('disposes scope when widget is removed from tree',
        (WidgetTester tester) async {
      final module = ParentModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                capturedScope = context.zenScope;
                return const Scaffold(body: Text('Test'));
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.isDisposed, false);

      // Remove widget from tree
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();

      expect(capturedScope!.isDisposed, true);
      expect(module.disposeCalled, true);
    });

    testWidgets('dependencies are accessible from child widgets',
        (WidgetTester tester) async {
      final parentModule = ParentModule();
      ParentService? foundService;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => parentModule,
            page: Builder(
              builder: (context) {
                foundService = context.findInScope<ParentService>();
                return Scaffold(
                  body: Text(foundService?.data ?? 'null'),
                );
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(foundService, isNotNull);
      expect(foundService!.data, 'parent-data');
      expect(find.text('parent-data'), findsOneWidget);
    });

    testWidgets('child scope can access parent dependencies',
        (WidgetTester tester) async {
      final parentModule = ParentModule();
      final childModule = ChildModule();

      ParentService? parentServiceInChild;
      ChildService? childService;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => parentModule,
            page: Builder(
              builder: (context) {
                return ZenRoute(
                  moduleBuilder: () => childModule,
                  page: Builder(
                    builder: (context) {
                      parentServiceInChild =
                          context.findInScope<ParentService>();
                      childService = context.findInScope<ChildService>();
                      return const Scaffold(body: Text('Child'));
                    },
                  ),
                  scopeName: 'ChildScope',
                );
              },
            ),
            scopeName: 'ParentScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(parentServiceInChild, isNotNull);
      expect(childService, isNotNull);
      expect(childService!.parentService, same(parentServiceInChild));
    });

    testWidgets('shows loading state during initialization',
        (WidgetTester tester) async {
      final module = ParentModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: const Scaffold(body: Text('Loaded')),
            scopeName: 'TestScope',
            loadingWidget: const Scaffold(
              body: Center(child: Text('Loading...')),
            ),
          ),
        ),
      );

      // Check for loading widget
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Loaded'), findsNothing);

      await tester.pumpAndSettle();

      // Check for loaded state
      expect(find.text('Loading...'), findsNothing);
      expect(find.text('Loaded'), findsOneWidget);
    });

    testWidgets('shows custom error widget on init failure',
        (WidgetTester tester) async {
      final errorModule = ErrorModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => errorModule,
            page: const Scaffold(body: Text('Success')),
            scopeName: 'ErrorScope',
            onError: (error) => Scaffold(
              body: Center(child: Text('Custom Error: $error')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Custom Error'), findsOneWidget);
      expect(find.text('Success'), findsNothing);
    });

    testWidgets('provides default error widget with retry',
        (WidgetTester tester) async {
      final errorModule = ErrorModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => errorModule,
            page: const Scaffold(body: Text('Success')),
            scopeName: 'ErrorScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load module'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('context extensions work correctly',
        (WidgetTester tester) async {
      final module = ParentModule();

      ZenScope? zenScope;
      ZenScope? zenScopeRequired;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                zenScope = context.zenScope;
                zenScopeRequired = context.zenScopeRequired;
                return const Scaffold(body: Text('Test'));
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(zenScope, isNotNull);
      expect(zenScopeRequired, isNotNull);
      expect(zenScope, same(zenScopeRequired));
    });

    testWidgets('nested scopes create proper hierarchy',
        (WidgetTester tester) async {
      final level1Module = ParentModule();
      final level2Module = ChildModule();

      ZenScope? level1Scope;
      ZenScope? level2Scope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => level1Module,
            page: Builder(
              builder: (context) {
                level1Scope = context.zenScope;
                return ZenRoute(
                  moduleBuilder: () => level2Module,
                  page: Builder(
                    builder: (context) {
                      level2Scope = context.zenScope;
                      return const Scaffold(body: Text('Level 2'));
                    },
                  ),
                  scopeName: 'Level2',
                );
              },
            ),
            scopeName: 'Level1',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(level1Scope, isNotNull);
      expect(level2Scope, isNotNull);
      expect(level2Scope!.parent, same(level1Scope));
      expect(level1Scope!.parent,
          same(Zen.rootScope)); // Top level uses RootScope as parent
    });

    testWidgets('disposing parent disposes children',
        (WidgetTester tester) async {
      final parentModule = ParentModule();
      final childModule = ChildModule();

      ZenScope? parentScope;
      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => parentModule,
            page: Builder(
              builder: (context) {
                parentScope = context.zenScope;
                return ZenRoute(
                  moduleBuilder: () => childModule,
                  page: Builder(
                    builder: (context) {
                      childScope = context.zenScope;
                      return const Scaffold(body: Text('Child'));
                    },
                  ),
                  scopeName: 'ChildScope',
                );
              },
            ),
            scopeName: 'ParentScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(parentScope!.isDisposed, false);
      expect(childScope!.isDisposed, false);

      // Remove parent widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();

      expect(parentScope!.isDisposed, true);
      expect(childScope!.isDisposed, true);
    });
  });

  group('ZenRoute - Error Recovery', () {
    testWidgets('retry button reinitializes module after error',
        (WidgetTester tester) async {
      var shouldFail = true;
      final failableModule = FailableModule(() => shouldFail);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => failableModule,
            page: const Scaffold(body: Text('Success')),
            scopeName: 'RetryScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially fails
      expect(find.text('Failed to load module'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Success'), findsNothing);

      // Fix the error and retry
      shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Should now succeed
      expect(find.text('Failed to load module'), findsNothing);
      expect(find.text('Success'), findsOneWidget);
    });

    testWidgets('error in register() is caught and shown',
        (WidgetTester tester) async {
      final module = RegisterErrorModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: const Scaffold(body: Text('Success')),
            scopeName: 'RegisterErrorScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Register failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('widget disposed during initialization handles gracefully',
        (WidgetTester tester) async {
      final slowModule = SlowInitModule();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => slowModule,
            page: const Scaffold(body: Text('Loaded')),
            scopeName: 'SlowScope',
          ),
        ),
      );

      // Start loading
      await tester.pump();
      expect(find.textContaining('Loading'), findsOneWidget);

      // Remove widget before init completes
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Empty'))),
      );

      // Allow any pending timers to complete
      await tester.pumpAndSettle();

      // Should not crash
      expect(find.text('Empty'), findsOneWidget);
      // Init should have completed because we used pumpAndSettle
      // which waits for async operations
    });
  });

  group('ZenRoute - Module Dependencies', () {
    testWidgets('initializes dependency modules before main module',
        (WidgetTester tester) async {
      final initOrder = <String>[];
      final dependency = TrackingModule('Dependency', initOrder);
      final main =
          TrackingModule('Main', initOrder, dependencies: [dependency]);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => main,
            page: const Scaffold(body: Text('Success')),
            scopeName: 'DependencyScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(initOrder, ['Dependency', 'Main']);
    });

    testWidgets(
        'child can access dependencies registered by dependency modules',
        (WidgetTester tester) async {
      final depModule = DependencyModuleA();
      final mainModule = MainModuleWithDep(dependencies: [depModule]);

      ServiceA? foundService;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => mainModule,
            page: Builder(
              builder: (context) {
                foundService = context.findInScopeOrNull<ServiceA>();
                return Scaffold(body: Text(foundService?.name ?? 'null'));
              },
            ),
            scopeName: 'DepTestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(foundService, isNotNull);
      expect(foundService!.name, 'ServiceA');
      expect(find.text('ServiceA'), findsOneWidget);
    });

    testWidgets('multiple dependency modules are all initialized',
        (WidgetTester tester) async {
      final initOrder = <String>[];
      final dep1 = TrackingModule('Dep1', initOrder);
      final dep2 = TrackingModule('Dep2', initOrder);
      final main =
          TrackingModule('Main', initOrder, dependencies: [dep1, dep2]);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => main,
            page: const Scaffold(body: Text('Success')),
            scopeName: 'MultiDepScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(initOrder, ['Dep1', 'Dep2', 'Main']);
    });
  });

  group('ZenRoute - Context Extensions', () {
    testWidgets('findInScope throws when dependency not found',
        (WidgetTester tester) async {
      final module = ParentModule();
      Object? caughtError;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                try {
                  context.findInScope<ChildService>();
                } catch (e) {
                  caughtError = e;
                }
                return const Scaffold(body: Text('Test'));
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(caughtError, isNotNull);
      expect(caughtError, isA<ZenDependencyNotFoundException>());
    });

    testWidgets('findInScopeOrNull returns null when dependency not found',
        (WidgetTester tester) async {
      final module = ParentModule();
      ChildService? foundService;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                foundService = context.findInScopeOrNull<ChildService>();
                return const Scaffold(body: Text('Test'));
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(foundService, isNull);
    });

    testWidgets('zenScopeRequired throws when no scope exists',
        (WidgetTester tester) async {
      Object? caughtError;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              try {
                context.zenScopeRequired;
              } catch (e) {
                caughtError = e;
              }
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(caughtError, isNotNull);
      expect(caughtError.toString(), contains('No ZenScope found'));
    });

    testWidgets('findInScope with tag finds tagged dependency',
        (WidgetTester tester) async {
      final module = TaggedModule();
      TestService? primary;
      TestService? secondary;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                primary = context.findInScope<TestService>(tag: 'primary');
                secondary = context.findInScope<TestService>(tag: 'secondary');
                return Scaffold(
                  body: Text('${primary?.name} ${secondary?.name}'),
                );
              },
            ),
            scopeName: 'TaggedScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(primary, isNotNull);
      expect(secondary, isNotNull);
      expect(primary!.name, 'primary-service');
      expect(secondary!.name, 'secondary-service');
      expect(find.text('primary-service secondary-service'), findsOneWidget);
    });
  });

  group('ZenRoute - Scope Name Generation', () {
    testWidgets('auto-generates scope name when not provided',
        (WidgetTester tester) async {
      final module = ParentModule();
      ZenScope? capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                capturedScope = context.zenScope;
                return const Scaffold(body: Text('Test'));
              },
            ),
            // No scopeName provided
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope!.name, startsWith('ZenRoute_'));
      // Auto-generated name uses page widget type (Builder in this case)
      expect(capturedScope!.name, contains('Builder'));
    });
  });

  group('ZenRoute - Advanced Scenarios', () {
    testWidgets('deep navigation stack (3+ levels) maintains hierarchy',
        (WidgetTester tester) async {
      final level1 = TrackingModule('Level1', []);
      final level2 = TrackingModule('Level2', []);
      final level3 = TrackingModule('Level3', []);

      ZenScope? scope1;
      ZenScope? scope2;
      ZenScope? scope3;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => level1,
            scopeName: 'Level1',
            page: Builder(
              builder: (context) {
                scope1 = context.zenScope;
                return ZenRoute(
                  moduleBuilder: () => level2,
                  scopeName: 'Level2',
                  page: Builder(
                    builder: (context) {
                      scope2 = context.zenScope;
                      return ZenRoute(
                        moduleBuilder: () => level3,
                        scopeName: 'Level3',
                        page: Builder(
                          builder: (context) {
                            scope3 = context.zenScope;
                            return const Scaffold(body: Text('Level 3'));
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(scope1, isNotNull);
      expect(scope2, isNotNull);
      expect(scope3, isNotNull);
      expect(scope3!.parent, same(scope2));
      expect(scope2!.parent, same(scope1));
      expect(scope1!.parent, same(Zen.rootScope));
    });

    testWidgets('module builder called only once per instance',
        (WidgetTester tester) async {
      var builderCallCount = 0;
      ZenModule moduleBuilder() {
        builderCallCount++;
        return ParentModule();
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: moduleBuilder,
            page: const Scaffold(body: Text('Test')),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(builderCallCount, 1);

      // Rebuild widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: moduleBuilder,
            page: const Scaffold(body: Text('Test')),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should still be 1 because didChangeDependencies checks _initialized
      expect(builderCallCount, 1);
    });

    testWidgets('default loading widget adapts to Scaffold presence',
        (WidgetTester tester) async {
      final slowModule = SlowInitModule();

      // Without surrounding Scaffold
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => slowModule,
            page: const Text('Loaded'),
            scopeName: 'NoScaffold',
          ),
        ),
      );

      await tester.pump();

      // Should create its own Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Loading'), findsOneWidget);

      // Wait for initialization to complete
      await tester.pumpAndSettle();
    });

    testWidgets('default error widget adapts to Scaffold presence',
        (WidgetTester tester) async {
      final errorModule = ErrorModule();

      // Without surrounding Scaffold
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => errorModule,
            page: const Text('Success'),
            scopeName: 'ErrorNoScaffold',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should create its own Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
      expect(find.text('Failed to load module'), findsOneWidget);
    });

    testWidgets('InheritedWidget updateShouldNotify works correctly',
        (WidgetTester tester) async {
      final module = ParentModule();
      var scopeChangeCount = 0;
      ZenScope? initialScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            key: const Key('route1'),
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                final scope = context.zenScope;
                if (initialScope != scope) {
                  scopeChangeCount++;
                  initialScope = scope;
                }
                return const Scaffold(body: Text('Test'));
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(scopeChangeCount, 1);

      // Rebuild with same scope instance (should not trigger update)
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            key: const Key('route1'),
            moduleBuilder: () => module,
            page: Builder(
              builder: (context) {
                final scope = context.zenScope;
                if (initialScope != scope) {
                  scopeChangeCount++;
                  initialScope = scope;
                }
                return const Scaffold(body: Text('Test'));
              },
            ),
            scopeName: 'TestScope',
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Count should still be 1 since _initialized prevents recreation
      expect(scopeChangeCount, 1);
    });
  });

  group('ZenRoute - Navigation & Hybrid Discovery', () {
    testWidgets('Sibling routes inherit scope via Zen.currentScope bridge',
        (WidgetTester tester) async {
      final parentModule = ParentModule();
      final childModule = ChildModule();

      ZenScope? parentScope;
      ZenScope? childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  // 1. Push Parent Route
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ZenRoute(
                        moduleBuilder: () => parentModule,
                        scopeName: 'ParentScope',
                        page: Builder(builder: (parentCtx) {
                          parentScope = parentCtx.zenScope;
                          // Added Scaffold to host the button properly
                          return Scaffold(
                            body: ElevatedButton(
                              onPressed: () {
                                // 2. Push Child Route (Sibling in Overlay)
                                Navigator.of(parentCtx).push(
                                  MaterialPageRoute(
                                    builder: (_) => ZenRoute(
                                      moduleBuilder: () => childModule,
                                      scopeName: 'ChildScope',
                                      page: Builder(builder: (childCtx) {
                                        childScope = childCtx.zenScope;
                                        // FIX: Added Scaffold+AppBar so tester.pageBack() can find the back button
                                        return Scaffold(
                                          appBar: AppBar(
                                              title: const Text('Child')),
                                          body: const Text('Child Page'),
                                        );
                                      }),
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Go to Child'),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
                child: const Text('Start'),
              );
            },
          ),
        ),
      );

      // Navigate to Parent
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(parentScope, isNotNull);
      expect(Zen.currentScope, parentScope,
          reason: 'Bridge should point to Parent');

      // Navigate to Child
      await tester.tap(find.text('Go to Child'));
      await tester.pumpAndSettle();

      // VERIFICATION 1: Child found Parent despite being a sibling
      expect(childScope, isNotNull);
      expect(childScope!.parent, same(parentScope),
          reason: 'Child should link to Parent via currentScope bridge');

      // VERIFICATION 2: Bridge updated to Child
      expect(Zen.currentScope, childScope);

      // Pop Child (Now works because AppBar is present)
      await tester.pageBack();
      await tester.pumpAndSettle();

      // VERIFICATION 3: Cleanup and Restoration
      expect(childScope!.isDisposed, true,
          reason: 'Child should be disposed on pop');
      expect(Zen.currentScope, parentScope,
          reason: 'Bridge should restore pointer to Parent');
    });

    testWidgets('Can override inheritance using parentScope parameter',
        (WidgetTester tester) async {
      final parentModule = ParentModule();

      ZenScope? parentScope;
      ZenScope? isolatedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => parentModule,
            scopeName: 'ParentScope',
            page: Builder(builder: (parentCtx) {
              parentScope = parentCtx.zenScope;
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(parentCtx).push(
                      MaterialPageRoute(
                        builder: (_) => ZenRoute(
                          moduleBuilder: () => ParentModule(),
                          scopeName: 'IsolatedScope',
                          // 🔥 EXPLICIT OVERRIDE
                          parentScope: Zen.rootScope,
                          page: Builder(builder: (ctx) {
                            isolatedScope = ctx.zenScope;
                            return Scaffold(
                              appBar: AppBar(title: const Text('Isolated')),
                              body: const Text('Isolated'),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                  child: const Text('Go Isolated'),
                ),
              );
            }),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Isolated Page
      await tester.tap(find.text('Go Isolated'));
      await tester.pumpAndSettle();

      // VERIFICATION: Parent is Root, NOT the previous page
      expect(isolatedScope!.parent, same(Zen.rootScope));
      expect(isolatedScope!.parent, isNot(parentScope));
    });
  });
}

// =============================================================================
// ERROR MODULE FOR TESTING
// =============================================================================

class ErrorModule extends ZenModule {
  @override
  String get name => 'ErrorModule';

  @override
  void register(ZenScope scope) {
    // Empty registration
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    throw Exception('Test initialization error');
  }
}

// Module that can fail or succeed based on a condition
class FailableModule extends ZenModule {
  final bool Function() shouldFail;

  FailableModule(this.shouldFail);

  @override
  String get name => 'FailableModule';

  @override
  void register(ZenScope scope) {
    // Empty registration
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    if (shouldFail()) {
      throw Exception('Intentional failure');
    }
  }
}

// Module that throws error during registration
class RegisterErrorModule extends ZenModule {
  @override
  String get name => 'RegisterErrorModule';

  @override
  void register(ZenScope scope) {
    throw Exception('Register failed');
  }
}

// Module with slow initialization
class SlowInitModule extends ZenModule {
  bool initCalled = false;

  @override
  String get name => 'SlowInitModule';

  @override
  void register(ZenScope scope) {
    // Empty registration
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    await Future.delayed(const Duration(milliseconds: 100));
    initCalled = true;
  }
}

// Module that tracks initialization order
class TrackingModule extends ZenModule {
  final String moduleName;
  final List<String> initOrder;
  @override
  final List<ZenModule> dependencies;

  TrackingModule(this.moduleName, this.initOrder,
      {this.dependencies = const []});

  @override
  String get name => moduleName;

  @override
  void register(ZenScope scope) {
    // Empty registration
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    initOrder.add(moduleName);
  }
}

// Test service for dependency testing
class ServiceA {
  final String name;
  ServiceA(this.name);
}

// Dependency module that registers ServiceA
class DependencyModuleA extends ZenModule {
  @override
  String get name => 'DependencyModuleA';

  @override
  void register(ZenScope scope) {
    scope.put<ServiceA>(ServiceA('ServiceA'));
  }
}

// Main module that depends on DependencyModuleA
class MainModuleWithDep extends ZenModule {
  @override
  final List<ZenModule> dependencies;

  MainModuleWithDep({required this.dependencies});

  @override
  String get name => 'MainModuleWithDep';

  @override
  void register(ZenScope scope) {
    // Can use ServiceA here because dependency was registered first
    scope.find<ServiceA>();
    // Empty registration, just testing dependency access
  }
}

// Module that registers tagged dependencies
class TaggedModule extends ZenModule {
  @override
  String get name => 'TaggedModule';

  @override
  void register(ZenScope scope) {
    scope.put<TestService>(TestService('primary-service'), tag: 'primary');
    scope.put<TestService>(TestService('secondary-service'), tag: 'secondary');
  }
}
