import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class TestService extends ZenController {
  final String name;
  bool disposed = false;
  TestService(this.name);

  @override
  void onClose() {
    disposed = true;
    super.onClose();
  }
}

void main() {
  setUp(() {
    Zen.init();
    ZenConfig.logLevel = ZenLogLevel.none;
  });
  tearDown(() {
    Zen.reset();
  });

  group('ZenConsumer Widget Tests', () {
    testWidgets('should find and provide existing dependency', (tester) async {
      final testService = TestService('test-service');
      Zen.put<TestService>(testService);

      bool builderCalled = false;
      TestService? receivedService;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            builder: (context, service) {
              builderCalled = true;
              receivedService = service;
              return Text(service.name);
            },
          ),
        ),
      );

      expect(builderCalled, isTrue);
      expect(receivedService, same(testService));
      expect(find.text('test-service'), findsOneWidget);
    });

    testWidgets('should handle missing dependency by throwing (fail fast)',
        (tester) async {
      bool errorHandlerCalled = false;
      FlutterError.onError = (FlutterErrorDetails details) {
        errorHandlerCalled = true;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ZenConsumer<TestService>(
                builder: (context, service) => Text(service.name),
              );
            },
          ),
        ),
      );

      expect(errorHandlerCalled, isTrue);
      FlutterError.onError = FlutterError.dumpErrorToConsole;
    });

    testWidgets('should find dependency with specific tag', (tester) async {
      final service1 = TestService('service-1');
      final service2 = TestService('service-2');

      Zen.put<TestService>(service1, tag: 'tag1');
      Zen.put<TestService>(service2, tag: 'tag2');

      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<TestService>(
            tag: 'tag2',
            builder: (context, service) => Text(service.name),
          ),
        ),
      );

      expect(find.text('service-2'), findsOneWidget);
    });

    testWidgets('should handle scope hierarchy via context extension',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget.create<TestService>(
            create: () => TestService('hierarchical-service'),
            child: ZenConsumer<TestService>(
              builder: (context, svc) => Text(svc.name),
            ),
          ),
        ),
      );

      expect(find.text('hierarchical-service'), findsOneWidget);
    });
  });
}
