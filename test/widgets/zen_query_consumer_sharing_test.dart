// test/widgets/zen_query_consumer_sharing_test.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  group('ZenQueryConsumer shared instance resolution', () {
    testWidgets(
        'multiple consumers with same queryKey share single query instance and deduplicate fetch',
        (tester) async {
      int fetchCount = 0;
      final completer = Completer<String>();

      await tester.pumpWidget(_wrap(
        Column(
          children: [
            ZenQueryConsumer<String>(
              queryKey: 'shared-user',
              fetcher: (_) {
                fetchCount++;
                return completer.future;
              },
              data: (user) => Text('Header: $user'),
              loading: () => const Text('loading-header'),
            ),
            ZenQueryConsumer<String>(
              queryKey: 'shared-user',
              fetcher: (_) {
                fetchCount++;
                return completer.future;
              },
              data: (user) => Text('Sidebar: $user'),
              loading: () => const Text('loading-sidebar'),
            ),
          ],
        ),
      ));

      // Both show loading
      expect(find.text('loading-header'), findsOneWidget);
      expect(find.text('loading-sidebar'), findsOneWidget);
      // Exactly 1 fetch fired (not 2)
      expect(fetchCount, 1);

      completer.complete('Alice');
      await tester.pumpAndSettle();

      // Both react to the same query result
      expect(find.text('Header: Alice'), findsOneWidget);
      expect(find.text('Sidebar: Alice'), findsOneWidget);

      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets(
        'unmounting one consumer does not dispose query if another consumer is still mounted',
        (tester) async {
      final completer = Completer<String>();
      bool showSidebar = true;

      await tester.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              ZenQueryConsumer<String>(
                queryKey: 'persistent-shared',
                fetcher: (_) => completer.future,
                data: (user) => Text('Header: $user'),
              ),
              if (showSidebar)
                ZenQueryConsumer<String>(
                  queryKey: 'persistent-shared',
                  fetcher: (_) => completer.future,
                  data: (user) => Text('Sidebar: $user'),
                ),
              ElevatedButton(
                onPressed: () => setState(() => showSidebar = false),
                child: const Text('toggle'),
              ),
            ],
          ),
        ),
      ));

      completer.complete('Bob');
      await tester.pumpAndSettle();

      expect(find.text('Header: Bob'), findsOneWidget);
      expect(find.text('Sidebar: Bob'), findsOneWidget);

      // Verify query is active in cache
      final query =
          ZenQueryCache.instance.getQuery<String>('persistent-shared');
      expect(query, isNotNull);
      expect(query!.isDisposed, isFalse);

      // Unmount the sidebar
      await tester.tap(find.text('toggle'));
      await tester.pumpAndSettle();

      // Sidebar is gone, header is still there
      expect(find.text('Sidebar: Bob'), findsNothing);
      expect(find.text('Header: Bob'), findsOneWidget);

      // Query is STILL active because Header is still mounted!
      expect(query.isDisposed, isFalse);

      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets('unmounting all consumers disposes the shared query',
        (tester) async {
      final completer = Completer<String>();
      bool showAll = true;

      await tester.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              if (showAll) ...[
                ZenQueryConsumer<String>(
                  queryKey: 'all-disposable',
                  fetcher: (_) => completer.future,
                  data: (user) => Text('A: $user'),
                ),
                ZenQueryConsumer<String>(
                  queryKey: 'all-disposable',
                  fetcher: (_) => completer.future,
                  data: (user) => Text('B: $user'),
                ),
              ],
              ElevatedButton(
                onPressed: () => setState(() => showAll = false),
                child: const Text('hideAll'),
              ),
            ],
          ),
        ),
      ));

      completer.complete('Charlie');
      await tester.pumpAndSettle();

      final query = ZenQueryCache.instance.getQuery<String>('all-disposable');
      expect(query, isNotNull);
      expect(query!.isDisposed, isFalse);

      // Hide all consumers
      await tester.tap(find.text('hideAll'));
      await tester.pumpAndSettle();

      // Query is now disposed because ref count dropped to 0
      expect(query.isDisposed, isTrue);
      expect(ZenQueryCache.instance.getQuery<String>('all-disposable'), isNull);

      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets(
        'does not dispose external controller-owned query when consumer unmounts',
        (tester) async {
      // 1. External controller creates and owns the query
      final controllerQuery = ZenQuery<String>(
        queryKey: 'controller-owned',
        fetcher: (_) async => 'controller-data',
      );

      bool showConsumer = true;

      await tester.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              if (showConsumer)
                ZenQueryConsumer<String>(
                  queryKey: 'controller-owned',
                  fetcher: (_) async => 'should-not-run',
                  data: (data) => Text('Consumer: $data'),
                ),
              ElevatedButton(
                onPressed: () => setState(() => showConsumer = false),
                child: const Text('unmount'),
              ),
            ],
          ),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('Consumer: controller-data'), findsOneWidget);

      // Unmount the consumer
      await tester.tap(find.text('unmount'));
      await tester.pumpAndSettle();

      expect(find.text('Consumer: controller-data'), findsNothing);

      // The controller-owned query MUST NOT be disposed!
      expect(controllerQuery.isDisposed, isFalse);
      expect(
        ZenQueryCache.instance.getQuery<String>('controller-owned'),
        isNotNull,
      );

      // Clean up controller query
      controllerQuery.dispose();
      await tester.binding.delayed(const Duration(minutes: 6));
    });

    testWidgets(
        'switching queryKey on one consumer updates only that consumer and preserves original query for other consumer',
        (tester) async {
      String consumer1Key = 'key-A';

      await tester.pumpWidget(_wrap(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              ZenQueryConsumer<String>(
                key: const ValueKey('c1'),
                queryKey: consumer1Key,
                fetcher: (k) async => 'data-$consumer1Key',
                data: (data) => Text('C1: $data'),
              ),
              ZenQueryConsumer<String>(
                key: const ValueKey('c2'),
                queryKey: 'key-A',
                fetcher: (_) async => 'data-key-A',
                data: (data) => Text('C2: $data'),
              ),
              ElevatedButton(
                onPressed: () => setState(() => consumer1Key = 'key-B'),
                child: const Text('switchKey'),
              ),
            ],
          ),
        ),
      ));

      await tester.pumpAndSettle();
      expect(find.text('C1: data-key-A'), findsOneWidget);
      expect(find.text('C2: data-key-A'), findsOneWidget);

      // Switch C1 to key-B
      await tester.tap(find.text('switchKey'));
      await tester.pumpAndSettle();

      expect(find.text('C1: data-key-B'), findsOneWidget);
      expect(find.text('C2: data-key-A'), findsOneWidget);

      // Key A is still active because C2 uses it
      expect(ZenQueryCache.instance.getQuery<String>('key-A'), isNotNull);
      expect(
        ZenQueryCache.instance.getQuery<String>('key-A')!.isDisposed,
        isFalse,
      );
      // Key B is active because C1 uses it
      expect(ZenQueryCache.instance.getQuery<String>('key-B'), isNotNull);
      expect(
        ZenQueryCache.instance.getQuery<String>('key-B')!.isDisposed,
        isFalse,
      );

      await tester.binding.delayed(const Duration(minutes: 6));
    });
  });
}
