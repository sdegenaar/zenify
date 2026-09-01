import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class _InitThrowingModule extends ZenModule {
  @override
  String get name => 'InitThrowingModule';

  @override
  void register(ZenScope scope) {}

  @override
  Future<void> onInit(ZenScope scope) async {
    throw Exception('Async module init failed');
  }

  @override
  Future<void> onDispose(ZenScope scope) async {}
}

class _DisposeThrowingModule extends ZenModule {
  @override
  String get name => 'DisposeThrowingModule';

  @override
  void register(ZenScope scope) {}

  @override
  Future<void> onInit(ZenScope scope) async {}

  @override
  Future<void> onDispose(ZenScope scope) {
    throw Exception('Module dispose failed');
  }
}

class _SimpleModule extends ZenModule {
  @override
  String get name => 'SimpleModule';

  @override
  void register(ZenScope scope) {
    scope.put<_SimpleController>(_SimpleController());
  }

  @override
  Future<void> onInit(ZenScope scope) async {}

  @override
  Future<void> onDispose(ZenScope scope) async {}
}

class _SimpleController extends ZenController {
  final count = 0.obs();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Widgets & Builders 100% Coverage Tests', () {
    testWidgets('ZenUpdater onError handler catches builder exceptions',
        (tester) async {
      var errorCaught = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider(
            moduleBuilder: () => _SimpleModule(),
            child: ZenUpdater<_SimpleController>(
              builder: (context, controller) {
                throw Exception('Builder crashed');
              },
              onError: (error) {
                errorCaught = true;
                return const Text('Error Handled');
              },
            ),
          ),
        ),
      );

      expect(find.text('Error Handled'), findsOneWidget);
      expect(errorCaught, isTrue);
    });

    testWidgets(
        'ZenEffectBuilder handles disposed effect with and without onInitial',
        (tester) async {
      final effect = ZenEffect<String>(name: 'disposed_test_effect');
      effect.dispose();

      // With onInitial
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onInitial: () => const Text('Initial Disposed State'),
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text(data),
            onError: (err) => Text(err.toString()),
          ),
        ),
      );

      expect(find.text('Initial Disposed State'), findsOneWidget);

      // Without onInitial
      await tester.pumpWidget(
        MaterialApp(
          home: ZenEffectBuilder<String>(
            effect: effect,
            onLoading: () => const Text('Loading'),
            onSuccess: (data) => Text(data),
            onError: (err) => Text(err.toString()),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets(
        'ZenStreamQueryBuilder default error widget and didUpdateWidget branches',
        (tester) async {
      final controller = StreamController<String>.broadcast();
      final streamQuery = ZenStreamQuery<String>(
        queryKey: 'stream_test_key',
        streamFn: () => controller.stream,
      );

      // 1. Test default error widget (when widget.error is null)
      await tester.pumpWidget(
        MaterialApp(
          home: ZenStreamQueryBuilder<String>(
            query: streamQuery,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      // Emit error into stream query
      controller.addError(Exception('Stream exploded'));
      await tester.pump();

      expect(find.textContaining('Stream Error:'), findsOneWidget);

      // 2. Test didUpdateWidget branches (keepPreviousData: false, query updates)
      final query2 = ZenStreamQuery<String>(
        queryKey: 'stream_test_key_2',
        streamFn: () => const Stream.empty(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZenStreamQueryBuilder<String>(
            query: query2,
            keepPreviousData: false,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      // Same query instance update with data
      controller.add('new_data');
      await tester.pumpWidget(
        MaterialApp(
          home: ZenStreamQueryBuilder<String>(
            query: streamQuery,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      streamQuery.dispose();
      query2.dispose();
      await controller.close();
    });

    testWidgets(
        'ZenProvider handles async module init error and scope replacement',
        (tester) async {
      FlutterErrorDetails? reportedError;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        reportedError = details;
      };

      // 1. Module async initialization failure surfaces to FlutterError.reportError
      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider(
            moduleBuilder: () => _InitThrowingModule(),
            child: const Text('Child Content'),
          ),
        ),
      );

      // Wait for async initialization
      await tester.pump(const Duration(milliseconds: 50));
      expect(reportedError, isNotNull);
      FlutterError.onError = originalOnError;

      // 2. Scope replacement in didUpdateWidget
      final scope1 = Zen.createScope(name: 'scope_1');
      final scope2 = Zen.createScope(name: 'scope_2');

      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider(
            scope: scope1,
            child: const Text('Scope 1'),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZenProvider(
            scope: scope2,
            child: const Text('Scope 2'),
          ),
        ),
      );

      expect(find.text('Scope 2'), findsOneWidget);
    });

    testWidgets('ZenRoute handles module disposal exceptions safely',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenRoute(
            moduleBuilder: () => _DisposeThrowingModule(),
            page: const Text('Route Page'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Route Page'), findsOneWidget);

      // Unmount ZenRoute to trigger dispose()
      await tester.pumpWidget(
        const MaterialApp(
          home: Text('Empty'),
        ),
      );
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('ZenObserver with ZenConfig.enablePerformanceMetrics enabled',
        (tester) async {
      ZenConfig.enablePerformanceMetrics = true;
      final count = 0.obs();

      await tester.pumpWidget(
        MaterialApp(
          home: ZenObserver(() => Text('Count: ${count.value}')),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
      count.value++;
      await tester.pump();
      expect(find.text('Count: 1'), findsOneWidget);

      ZenConfig.enablePerformanceMetrics = false;
    });
  });
}
