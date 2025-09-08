// test/widgets/zen_scope_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test controller that extends ZenController
class CounterController extends ZenController {
  int count = 0;

  void increment() {
    count++;
    update(); // Notify all listeners
  }

  void incrementWithId(String id) {
    count++;
    update([id]); // Notify specific listeners
  }
}

// Test service for dependency injection
class TestService {
  String getValue() => 'test-value';
}

// Test module for module-based dependency injection
class TestModule extends ZenModule {
  @override
  String get name => 'TestModule';

  @override
  List<ZenModule> get dependencies => [];

  @override
  void register(ZenScope scope) {
    scope.put<CounterController>(CounterController());
    scope.put<TestService>(TestService());
  }
}

// Test module that depends on another module
class DependentModule extends ZenModule {
  @override
  String get name => 'DependentModule';

  @override
  List<ZenModule> get dependencies => [TestModule()];

  @override
  void register(ZenScope scope) {
    // This module depends on TestService from TestModule
    final service = scope.find<TestService>();
    if (service != null) {
      scope.put<String>(service.getValue(), tag: 'serviceValue');
    } else {
      scope.put<String>('fallback-value', tag: 'serviceValue');
    }
  }
}

void main() {
  setUp(() {
    // Initialize Zen
    Zen.init();
    ZenConfig.enableDebugLogs = false;
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenScopeWidget Tests', () {
    testWidgets('should create and access a scope using scope parameter',
        (WidgetTester tester) async {
      late ZenScope capturedScope;
      final customScope = Zen.createScope(name: 'TestScope');

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            scope: customScope,
            child: Builder(
              builder: (context) {
                capturedScope = ZenScopeWidget.of(context);
                return const Text('Inside Scope');
              },
            ),
          ),
        ),
      );

      expect(capturedScope, isNotNull);
      expect(capturedScope, equals(customScope));
      expect(capturedScope.name, 'TestScope');
      expect(find.text('Inside Scope'), findsOneWidget);
    });

    testWidgets('should create a scope from a module using moduleBuilder',
        (WidgetTester tester) async {
      late ZenScope capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            moduleBuilder: () => TestModule(),
            child: Builder(
              builder: (context) {
                capturedScope = ZenScopeWidget.of(context);
                return const Text('Inside Module Scope');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope.name, 'TestModule');
      expect(find.text('Inside Module Scope'), findsOneWidget);

      // Verify the module registered its dependencies
      final controller = capturedScope.find<CounterController>();
      final service = capturedScope.find<TestService>();
      expect(controller, isNotNull);
      expect(service, isNotNull);
    });

    testWidgets('should use custom scopeName if provided',
        (WidgetTester tester) async {
      late ZenScope capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            moduleBuilder: () => TestModule(),
            scopeName: 'CustomModuleScope',
            child: Builder(
              builder: (context) {
                capturedScope = ZenScopeWidget.of(context);
                return const Text('Inside Custom Scope');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);
      expect(capturedScope.name, 'CustomModuleScope');
      expect(find.text('Inside Custom Scope'), findsOneWidget);
    });

    testWidgets('should register module dependencies',
        (WidgetTester tester) async {
      late ZenScope capturedScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            moduleBuilder: () => DependentModule(),
            child: Builder(
              builder: (context) {
                capturedScope = ZenScopeWidget.of(context);
                return const Text('Dependent Module Scope');
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(capturedScope, isNotNull);

      // Verify that dependencies from TestModule are registered
      final service = capturedScope.find<TestService>();
      expect(service, isNotNull);

      // Verify that DependentModule's own registrations work
      final serviceValue = capturedScope.find<String>(tag: 'serviceValue');
      expect(serviceValue, equals('test-value'));
    });

    testWidgets('should create nested scopes with correct hierarchy',
        (WidgetTester tester) async {
      late ZenScope parentScope;
      late ZenScope childScope;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            moduleBuilder: () => TestModule(),
            child: Builder(
              builder: (parentContext) {
                parentScope = ZenScopeWidget.of(parentContext);
                return ZenScopeWidget(
                  moduleBuilder: () => DependentModule(),
                  child: Builder(
                    builder: (childContext) {
                      childScope = ZenScopeWidget.of(childContext);
                      return const Text('Nested Scope');
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(childScope.parent, equals(parentScope));
      expect(find.text('Nested Scope'), findsOneWidget);

      // Verify that child scope can access parent scope's services
      final parentService = parentScope.find<TestService>();
      final childServiceFromParent = childScope.find<TestService>();

      // The TestService should be accessible from both scopes, but they might be different instances
      expect(parentService, isNotNull);
      expect(childServiceFromParent, isNotNull);

      // Verify that child-specific dependency is only in child scope
      final serviceValue = childScope.find<String>(tag: 'serviceValue');
      expect(serviceValue, equals('test-value'));
      expect(parentScope.find<String>(tag: 'serviceValue'), isNull);
    });

    testWidgets(
        'should maintain separate controller instances in different scopes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              // First scoped counter
              ZenScopeWidget(
                moduleBuilder: () => TestModule(),
                scopeName: 'Scope1',
                child: Builder(
                  builder: (context) {
                    final scope = ZenScopeWidget.of(context);
                    return ZenBuilder<CounterController>(
                      scope: scope,
                      builder: (context, controller) {
                        return ElevatedButton(
                          onPressed: controller.increment,
                          child: Text('Counter 1: ${controller.count}'),
                        );
                      },
                    );
                  },
                ),
              ),
              // Second scoped counter
              ZenScopeWidget(
                moduleBuilder: () => TestModule(),
                scopeName: 'Scope2',
                child: Builder(
                  builder: (context) {
                    final scope = ZenScopeWidget.of(context);
                    return ZenBuilder<CounterController>(
                      scope: scope,
                      builder: (context, controller) {
                        return ElevatedButton(
                          onPressed: controller.increment,
                          child: Text('Counter 2: ${controller.count}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );

      // Wait for initial state to settle
      await tester.pumpAndSettle();

      // Initially both counters should be 0
      expect(find.text('Counter 1: 0'), findsOneWidget);
      expect(find.text('Counter 2: 0'), findsOneWidget);

      // Tap first counter button
      await tester.tap(find.text('Counter 1: 0'));
      await tester.pumpAndSettle();

      // First counter should update, second should stay the same
      expect(find.text('Counter 1: 1'), findsOneWidget);
      expect(find.text('Counter 2: 0'), findsOneWidget);

      // Tap second counter button
      await tester.tap(find.text('Counter 2: 0'));
      await tester.pumpAndSettle();

      // Both counters should be updated independently
      expect(find.text('Counter 1: 1'), findsOneWidget);
      expect(find.text('Counter 2: 1'), findsOneWidget);
    });

    testWidgets('should clean up scope when widget is disposed',
        (WidgetTester tester) async {
      // Use a unique controller so we can verify it's disposed
      final controller = CounterController();
      final testScope = Zen.createScope(name: 'DisposableScope');
      testScope.put<CounterController>(controller);

      // Keep a weak reference to detect if the controller is garbage collected
      bool isControllerDisposed = false;
      controller.addDisposer(() {
        isControllerDisposed = true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            scope: testScope,
            child: const Text('Disposable'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify setup
      expect(find.text('Disposable'), findsOneWidget);
      expect(isControllerDisposed, isFalse);

      // Dispose by replacing the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Replaced'),
        ),
      );

      // Only the controller should be disposed, not the scope since we provided it
      expect(isControllerDisposed, isFalse);
      expect(testScope.isDisposed, isFalse);

      // Now create a test with an owned scope
      isControllerDisposed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget(
            moduleBuilder: () => TestModule(),
            child: const Text('Owned Scope'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Replace the widget, forcing disposal
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Replaced Again'),
        ),
      );

      // Verify UI updated
      expect(find.text('Owned Scope'), findsNothing);
      expect(find.text('Replaced Again'), findsOneWidget);
    });

    testWidgets('should use new module when moduleBuilder changes',
        (WidgetTester tester) async {
      // Use StatefulBuilder instead of a custom class
      bool useTestModule = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        useTestModule = !useTestModule;
                      });
                    },
                    child: const Text('Toggle Module'),
                  ),
                  ZenScopeWidget(
                    moduleBuilder: () =>
                        useTestModule ? TestModule() : DependentModule(),
                    child: Builder(
                      builder: (context) {
                        final scope = ZenScopeWidget.of(context);
                        final hasServiceValue =
                            scope.find<String>(tag: 'serviceValue') != null;

                        return Text(
                          useTestModule
                              ? 'Using TestModule'
                              : 'Using DependentModule: $hasServiceValue',
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially should use TestModule
      expect(find.text('Using TestModule'), findsOneWidget);

      // Toggle to DependentModule
      await tester.tap(find.text('Toggle Module'));
      await tester.pumpAndSettle();

      // Now should use DependentModule
      expect(find.text('Using DependentModule: true'), findsOneWidget);
    });

    testWidgets('ZenScopeWidget.of() should throw when no scope is found',
        (WidgetTester tester) async {
      bool didThrow = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              try {
                ZenScopeWidget.of(context);
              } catch (e) {
                didThrow = true;
              }
              return const Text('Tried to find scope');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(didThrow, isTrue);
      expect(find.text('Tried to find scope'), findsOneWidget);
    });

    testWidgets(
        'ZenScopeWidget.maybeOf() should return null when no scope is found',
        (WidgetTester tester) async {
      late ZenScope? nullScope;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              nullScope = ZenScopeWidget.maybeOf(context);
              return const Text('No Scope');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(nullScope, isNull);
      expect(find.text('No Scope'), findsOneWidget);
    });
  });
}
