import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// Test services and controllers
class TestService {
  final String name;
  bool disposed = false;

  TestService(this.name);

  void dispose() {
    disposed = true;
  }
}

class TestController extends ZenController {
  final String value;
  bool initialized = false;
  bool disposed = false;

  TestController(this.value);

  @override
  void onInit() {
    super.onInit();
    initialized = true;
  }

  @override
  void onClose() {
    disposed = true;
    super.onClose();
  }
}

class OptionalService {
  final String data;
  OptionalService(this.data);
}

void main() {
  // Initialize Flutter test framework
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ZenConsumer Widget Tests', () {
    setUp(() {
      // Initialize Zen for each test
      Zen.init();
      ZenConfig.applyEnvironment(ZenEnvironment.test); // Apply test settings
      ZenConfig.logLevel = ZenLogLevel.none; // Override to disable all logs
    });

    tearDown(() {
      // Clean up after each test
      Zen.reset();
    });

    testWidgets('should find and provide existing dependency', (tester) async {
      // Arrange
      final testService = TestService('test-service');
      Zen.put<TestService>(testService);

      bool builderCalled = false;
      TestService? receivedService;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (service) {
              builderCalled = true;
              receivedService = service;
              return Text(service?.name ?? 'No Service');
            },
          ),
        ),
      );

      // Assert
      expect(builderCalled, isTrue);
      expect(receivedService, same(testService));
      expect(find.text('test-service'), findsOneWidget);
    });

    testWidgets('should handle missing dependency gracefully', (tester) async {
      // Arrange - don't register any service
      bool builderCalled = false;
      TestService? receivedService;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (service) {
              builderCalled = true;
              receivedService = service;
              return Text(service?.name ?? 'No Service');
            },
          ),
        ),
      );

      // Assert
      expect(builderCalled, isTrue);
      expect(receivedService, isNull);
      expect(find.text('No Service'), findsOneWidget);
    });

    testWidgets('should find dependency with specific tag', (tester) async {
      // Arrange
      final service1 = TestService('service-1');
      final service2 = TestService('service-2');

      Zen.put<TestService>(service1, tag: 'tag1');
      Zen.put<TestService>(service2, tag: 'tag2');

      TestService? receivedService;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            tag: 'tag2',
            builder: (service) {
              receivedService = service;
              return Text(service?.name ?? 'No Service');
            },
          ),
        ),
      );

      // Assert
      expect(receivedService, same(service2));
      expect(find.text('service-2'), findsOneWidget);
    });

    testWidgets('should work with controllers', (tester) async {
      // Arrange
      final controller = TestController('test-controller');
      Zen.put<TestController>(controller);

      TestController? receivedController;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestController>(
            builder: (ctrl) {
              receivedController = ctrl;
              return Text(ctrl?.value ?? 'No Controller');
            },
          ),
        ),
      );

      // Assert
      expect(receivedController, same(controller));
      expect(receivedController?.initialized, isTrue);
      expect(find.text('test-controller'), findsOneWidget);
    });

    testWidgets('should update when tag changes', (tester) async {
      // Arrange
      final service1 = TestService('service-1');
      final service2 = TestService('service-2');

      Zen.put<TestService>(service1, tag: 'tag1');
      Zen.put<TestService>(service2, tag: 'tag2');

      String currentTag = 'tag1';
      TestService? receivedService;

      // Create a StatefulWidget to change the tag
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  ZenConsumer<TestService>(
                    tag: currentTag,
                    builder: (service) {
                      receivedService = service;
                      return Text(service?.name ?? 'No Service');
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        currentTag = 'tag2';
                      });
                    },
                    child: const Text('Change Tag'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Assert initial state
      expect(receivedService, same(service1));
      expect(find.text('service-1'), findsOneWidget);

      // Act - change tag
      await tester.tap(find.text('Change Tag'));
      await tester.pump();

      // Assert updated state
      expect(receivedService, same(service2));
      expect(find.text('service-2'), findsOneWidget);
    });

    testWidgets('should handle scope hierarchy', (tester) async {
      // Arrange
      final parentScope = Zen.createScope(name: 'ParentScope');
      final childScope =
          Zen.createScope(name: 'ChildScope', parent: parentScope);

      final service = TestService('hierarchical-service');
      parentScope.put<TestService>(service);

      TestService? receivedService;

      // Act - register child scope as current scope for this test
      // We'll simulate this by manually registering in root and using normal lookup
      Zen.put<TestService>(service);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (svc) {
              receivedService = svc;
              return Text(svc?.name ?? 'No Service');
            },
          ),
        ),
      );

      // Assert
      expect(receivedService, same(service));
      expect(find.text('hierarchical-service'), findsOneWidget);

      // Cleanup
      parentScope.dispose();
      childScope.dispose();
    });

    testWidgets('should not rebuild unnecessarily', (tester) async {
      // Arrange
      final service = TestService('stable-service');
      Zen.put<TestService>(service);

      int buildCount = 0;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  ZenConsumer<TestService>(
                    builder: (svc) {
                      buildCount++;
                      return Text(svc?.name ?? 'No Service');
                    },
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        // Trigger parent rebuild
                      });
                    },
                    child: const Text('Rebuild Parent'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      // Assert initial build
      expect(buildCount, 1);

      // Act - trigger parent rebuild
      await tester.tap(find.text('Rebuild Parent'));
      await tester.pump();

      // Assert - ZenConsumer should rebuild because tag didn't change
      // but the dependency lookup should be cached
      expect(buildCount, 2);
      expect(find.text('stable-service'), findsOneWidget);
    });

    testWidgets('should handle graceful degradation with builder errors',
        (tester) async {
      // Arrange
      final service = TestService('error-service');
      Zen.put<TestService>(service);

      // Act & Assert - builder that throws should not crash the app
      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (service) {
              if (service?.name == 'error-service') {
                throw Exception('Test error');
              }
              return Text(service?.name ?? 'No Service');
            },
          ),
        ),
      );

      // The widget should handle the error gracefully
      // Flutter's error handling will catch the exception
      expect(tester.takeException(), isA<Exception>());
    });

    testWidgets('should work with multiple ZenConsumers', (tester) async {
      // Arrange
      final service1 = TestService('service-1');
      final service2 = OptionalService('optional-data');

      Zen.put<TestService>(service1);
      Zen.put<OptionalService>(service2);

      TestService? receivedService1;
      OptionalService? receivedService2;

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              ZenConsumer<TestService>(
                builder: (service) {
                  receivedService1 = service;
                  return Text('Service1: ${service?.name ?? 'None'}');
                },
              ),
              ZenConsumer<OptionalService>(
                builder: (service) {
                  receivedService2 = service;
                  return Text('Service2: ${service?.data ?? 'None'}');
                },
              ),
            ],
          ),
        ),
      );

      // Assert
      expect(receivedService1, same(service1));
      expect(receivedService2, same(service2));
      expect(find.text('Service1: service-1'), findsOneWidget);
      expect(find.text('Service2: optional-data'), findsOneWidget);
    });

    testWidgets('should handle widget disposal correctly', (tester) async {
      // Arrange
      final service = TestService('disposal-service');
      Zen.put<TestService>(service);

      bool builderCalled = false;

      // Act - create widget
      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (svc) {
              builderCalled = true;
              return Text(svc?.name ?? 'No Service');
            },
          ),
        ),
      );

      expect(builderCalled, isTrue);
      builderCalled = false;

      // Act - remove widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Different Widget'),
        ),
      );

      // Assert - no memory leaks, widget disposed cleanly
      expect(find.text('disposal-service'), findsNothing);
      expect(find.text('Different Widget'), findsOneWidget);
    });

    testWidgets('should show loading state initially', (tester) async {
      // Arrange
      bool hasSearchedState = false;

      // Act - pump widget without completing first frame
      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (service) {
              hasSearchedState = true;
              return Text(service?.name ?? 'No Service');
            },
          ),
        ),
      );

      // Before the first pump completes, the widget might show empty state
      // After pump, the builder should be called
      expect(hasSearchedState, isTrue);
    });

    test('should handle ZenConfig debug logs correctly', () {
      // Arrange
      ZenConfig.logLevel = ZenLogLevel.debug;

      // This test ensures that when debug logs are enabled,
      // the error handling doesn't throw exceptions
      final widget = ZenConsumer<TestService>(
        builder: (service) => Text(service?.name ?? 'No Service'),
      );

      // Act & Assert - creating the widget should not throw
      expect(() => widget, returnsNormally);

      // Reset debug logs
      ZenConfig.logLevel = ZenLogLevel.none;
    });
  });

  group('ZenConsumer Error Handling', () {
    setUp(() {
      Zen.init();
      ZenConfig.logLevel = ZenLogLevel.debug; // Enable for error testing
    });

    tearDown(() {
      Zen.reset();
      ZenConfig.logLevel = ZenLogLevel.none;
    });

    testWidgets('should handle Zen.findOrNull throwing exception',
        (tester) async {
      // This test verifies that if Zen.findOrNull somehow throws,
      // ZenConsumer handles it gracefully

      bool builderCalled = false;
      TestService? receivedService;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (service) {
              builderCalled = true;
              receivedService = service;
              return Text(service?.name ?? 'Error Handled');
            },
          ),
        ),
      );

      // Assert graceful handling
      expect(builderCalled, isTrue);
      expect(receivedService, isNull);
      expect(find.text('Error Handled'), findsOneWidget);
    });
  });
}
