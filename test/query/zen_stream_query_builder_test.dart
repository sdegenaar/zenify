import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenStreamQueryBuilder UI', () {
    testWidgets('shows loading initially', (tester) async {
      final controller = StreamController<String>();
      final query = ZenStreamQuery<String>(
        queryKey: 'ui-test',
        streamFn: () => controller.stream,
      );

      await tester.pumpWidget(MaterialApp(
        home: ZenStreamQueryBuilder<String>(
          query: query,
          builder: (context, data) => Text(data),
          loading: () => const Text('Loading...'),
        ),
      ));

      expect(find.text('Loading...'), findsOneWidget);

      // CLEANUP: Unmount widget FIRST
      await tester.pumpWidget(const SizedBox());

      query.dispose();
      controller.close();
    });

    testWidgets('shows data when emitted', (tester) async {
      final controller = StreamController<String>();
      final query = ZenStreamQuery<String>(
        queryKey: 'ui-test-data',
        streamFn: () => controller.stream,
      );

      await tester.pumpWidget(MaterialApp(
        home: ZenStreamQueryBuilder<String>(
          query: query,
          builder: (context, data) => Text('Data: $data'),
        ),
      ));

      controller.add('Hello');
      // Use pump() to process microtasks instead of Future.delayed
      await tester.pump();

      expect(find.text('Data: Hello'), findsOneWidget);

      // CLEANUP: Unmount widget FIRST
      await tester.pumpWidget(const SizedBox());

      query.dispose();
      controller.close();
    });

    testWidgets('shows error widget on failure', (tester) async {
      final controller = StreamController<String>();
      final query = ZenStreamQuery<String>(
        queryKey: 'ui-test-error',
        streamFn: () => controller.stream,
      );

      await tester.pumpWidget(MaterialApp(
        home: ZenStreamQueryBuilder<String>(
          query: query,
          builder: (context, data) => Text(data),
          error: (e) => Text('Error: $e'),
        ),
      ));

      controller.addError('Network Fail');
      await tester.pump();

      expect(find.text('Error: Network Fail'), findsOneWidget);

      // CLEANUP: Unmount widget FIRST
      await tester.pumpWidget(const SizedBox());

      query.dispose();
      controller.close();
    });

    testWidgets('shows empty widget if provided and data is empty iterable',
        (tester) async {
      final controller = StreamController<List<String>>();
      final query = ZenStreamQuery<List<String>>(
        queryKey: 'ui-test-empty',
        streamFn: () => controller.stream,
      );

      await tester.pumpWidget(MaterialApp(
        home: ZenStreamQueryBuilder<List<String>>(
          query: query,
          builder: (context, data) => Column(
            children: data.map((e) => Text(e)).toList(),
          ),
          empty: () => const Text('No Items'),
        ),
      ));

      controller.add([]);
      await tester.pump();

      expect(find.text('No Items'), findsOneWidget);

      // CLEANUP: Unmount widget FIRST
      await tester.pumpWidget(const SizedBox());

      query.dispose();
      controller.close();
    });
  });

  testWidgets('keepPreviousData maintains old stream data during switch',
      (tester) async {
    final controller1 = StreamController<String>.broadcast();

    final query1 = ZenStreamQuery<String>(
      queryKey: 's1',
      streamFn: () => controller1.stream,
      initialData: 'Stream 1',
    );

    final queryNotifier = ValueNotifier<ZenStreamQuery<String>>(query1);

    // Build widget tree ONCE with ValueNotifier
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<ZenStreamQuery<String>>(
          valueListenable: queryNotifier,
          builder: (context, query, child) {
            return ZenStreamQueryBuilder<String>(
              key: const GlobalObjectKey('stream-builder'),
              query: query,
              keepPreviousData: true,
              builder: (context, data) => Text(data),
              loading: () => const Text('Loading...'),
            );
          },
        ),
      ),
    ));

    expect(find.text('Stream 1'), findsOneWidget);

    // Create query2 AFTER query1 is shown
    final controller2 = StreamController<String>.broadcast();
    final query2 = ZenStreamQuery<String>(
      queryKey: 's2',
      streamFn: () => controller2.stream,
      // No initial data, so it starts loading
    );

    // Switch to Query 2
    queryNotifier.value = query2;
    await tester.pump(); // Trigger rebuild

    // Should still show Stream 1 data
    expect(find.text('Stream 1'), findsOneWidget);
    expect(find.text('Loading...'), findsNothing);

    // Emit data on Stream 2
    controller2.add('Stream 2');
    await tester.pumpAndSettle();

    // Now shows Stream 2 data
    expect(find.text('Stream 2'), findsOneWidget);

    // Cleanup
    await tester.pumpWidget(const SizedBox());
    query1.dispose();
    query2.dispose();
    controller1.close();
    controller2.close();
  });
}
