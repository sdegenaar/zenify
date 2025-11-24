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
}
