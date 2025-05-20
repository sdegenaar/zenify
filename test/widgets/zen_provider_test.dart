// test/widgets/zen_provider_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenify/zenify.dart';

// Simple service class for testing
class TestService {
  final String value;
  TestService(this.value);

  @override
  String toString() => 'TestService(value: $value)';
}

// Secondary service to test multiple dependencies
class LoggingService {
  final bool enabled;
  LoggingService(this.enabled);

  @override
  String toString() => 'LoggingService(enabled: $enabled)';
}

void main() {
  setUp(() {
    // Initialize a fresh Zen environment
    try {
      final container = ProviderContainer();
      Zen.init(container);
    } catch (e) {
      // Already initialized
    }

    // Make sure we're in test mode
    ZenTest.setupTestEnvironment();

    // Clean any existing dependencies
    Zen.deleteAll(force: true);
  });

  tearDown(() {
    ZenTest.resetTestEnvironment();
  });

  group('ZenProvider Tests', () {
    test('direct registration works', () {
      final service = TestService('direct-value');
      Zen.putDependency(service);

      final found = Zen.findDependency<TestService>();
      expect(found, isNotNull);
      expect(found?.value, 'direct-value');
    });

    testWidgets('ZenProvider correctly registers dependencies', (WidgetTester tester) async {
      // Build the widget tree with ZenProvider
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ZenProvider(
              dependencies: {
                TestService: () => TestService('widget-test-value'),
              },
              child: Builder(
                builder: (context) {
                  final service = ZenTest.get<TestService>(context) ??
                      Zen.findDependency<TestService>();
                  return Text('Value: ${service?.value ?? "NOT FOUND"}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Value: widget-test-value'), findsOneWidget);
    });

    testWidgets('ZenProvider supports multiple dependencies', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ZenProvider(
              dependencies: {
                TestService: () => TestService('test-value'),
                LoggingService: () => LoggingService(true),
              },
              child: Builder(
                builder: (context) {
                  final testService = ZenTest.get<TestService>(context) ??
                      Zen.findDependency<TestService>();
                  final loggingService = ZenTest.get<LoggingService>(context) ??
                      Zen.findDependency<LoggingService>();

                  return Column(
                    children: [
                      Text('Test: ${testService?.value ?? "NOT FOUND"}'),
                      Text('Logging: ${loggingService?.enabled == true ? "true" : "false"}'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Test: test-value'), findsOneWidget);
      expect(find.text('Logging: true'), findsOneWidget);
    });

    testWidgets('ZenProvider respects scopes', (WidgetTester tester) async {
      // Create a custom scope
      final customScope = ZenScope(name: 'TestScope');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ZenProvider(
              scope: customScope,
              dependencies: {
                TestService: () => TestService('scoped-value'),
              },
              child: Builder(
                builder: (context) {
                  final serviceFromWidget = ZenTest.get<TestService>(context);
                  final serviceFromScope = serviceFromWidget ??
                      Zen.findDependency<TestService>(scope: customScope);

                  return Text('Value: ${serviceFromScope?.value ?? "NOT FOUND"}');
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Value: scoped-value'), findsOneWidget);
    });

  });
}