// test/widgets/zen_v2_regression_test.dart
//
// Regression tests for V2-specific behaviour:
//   1. ZenBuilder deprecated alias parity with ZenUpdater
//   2. ZenUpdater ID-targeted selective rebuilds
//   3. ZenScopeWidget.create controller disposal on widget removal
//   4. initController reactive (.obs()) rebuild inside ZenView
//   5. ZenConsumer scope-bound (finds scoped controller, not global)
//
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

// ─── Shared controllers ────────────────────────────────────────────────────

class CountController extends ZenController {
  final count = 0.obs();
  int plainCount = 0;
  bool disposed = false;

  void incrementReactive() => count.value++;

  void incrementPlain([String? id]) {
    plainCount++;
    if (id != null) {
      update([id]);
    } else {
      update(); // broadcast — notifies all ZenUpdater/ZenBuilder widgets
    }
  }

  @override
  void onClose() {
    disposed = true;
    super.onClose();
  }
}

// ─── Test fixtures ─────────────────────────────────────────────────────────

/// ZenView that reacts to an owned controller's .obs() value.
class ReactiveOwnedView extends ZenView<CountController> {
  const ReactiveOwnedView({super.key});

  @override
  CountController Function() get initController => CountController.new;

  @override
  Widget build(BuildContext context, CountController controller) {
    return Column(
      children: [
        // Must rebuild when count.value changes via ZenObserver
        ZenObserver(() => Text('reactive:${controller.count.value}')),
        ElevatedButton(
          onPressed: controller.incrementReactive,
          child: const Text('inc'),
        ),
      ],
    );
  }
}

/// ZenView that uses ID-targeted ZenUpdater internally.
class IdUpdaterView extends ZenView<CountController> {
  const IdUpdaterView({super.key});

  @override
  Widget build(BuildContext context, CountController controller) {
    return Column(
      children: [
        ZenUpdater<CountController>(
          id: 'counter-a',
          builder: (ctx, ctrl) => Text('a:${ctrl.plainCount}'),
        ),
        ZenUpdater<CountController>(
          id: 'counter-b',
          builder: (ctx, ctrl) => Text('b:${ctrl.plainCount}'),
        ),
        ElevatedButton(
          onPressed: () => controller.incrementPlain('counter-a'),
          child: const Text('inc-a'),
        ),
      ],
    );
  }
}

// ─── Tests ─────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    Zen.init();
    ZenConfig.logLevel = ZenLogLevel.none;
  });

  tearDown(() {
    Zen.reset();
  });

  // ── 1. ZenBuilder deprecated alias ───────────────────────────────────────

  group('ZenBuilder deprecated alias', () {
    testWidgets('ZenBuilder is identical to ZenUpdater at runtime',
        (tester) async {
      final ctrl = CountController();
      Zen.put<CountController>(ctrl);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenBuilder<CountController>(
            // ignore: deprecated_member_use
            builder: (context, c) => Text('alias:${c.plainCount}'),
          ),
        ),
      );

      expect(find.text('alias:0'), findsOneWidget);

      ctrl.incrementPlain(); // broadcast update() — notifies all
      await tester.pump();

      expect(find.text('alias:1'), findsOneWidget);
    });

    testWidgets('ZenBuilder and ZenUpdater both respond to the same update()',
        (tester) async {
      final ctrl = CountController();
      Zen.put<CountController>(ctrl);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              ZenUpdater<CountController>(
                builder: (ctx, c) => Text('updater:${c.plainCount}'),
              ),
              ZenBuilder<CountController>(
                // ignore: deprecated_member_use
                builder: (ctx, c) => Text('builder:${c.plainCount}'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('updater:0'), findsOneWidget);
      expect(find.text('builder:0'), findsOneWidget);

      ctrl.incrementPlain(); // broadcast
      await tester.pump();

      expect(find.text('updater:1'), findsOneWidget);
      expect(find.text('builder:1'), findsOneWidget);
    });
  });

  // ── 2. ZenUpdater ID-targeted selective rebuilds ─────────────────────────

  group('ZenUpdater ID-targeted rebuilds', () {
    testWidgets('update([id]) only rebuilds matching ZenUpdater',
        (tester) async {
      final ctrl = CountController();
      Zen.put<CountController>(ctrl);

      int buildsA = 0;
      int buildsB = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              ZenUpdater<CountController>(
                id: 'a',
                builder: (ctx, c) {
                  buildsA++;
                  return Text('a:${c.plainCount}');
                },
              ),
              ZenUpdater<CountController>(
                id: 'b',
                builder: (ctx, c) {
                  buildsB++;
                  return Text('b:${c.plainCount}');
                },
              ),
            ],
          ),
        ),
      );

      final initialBuildsA = buildsA;
      final initialBuildsB = buildsB;

      // Only notify 'a'
      ctrl.incrementPlain('a');
      await tester.pump();

      expect(find.text('a:1'), findsOneWidget);
      expect(find.text('b:0'), findsOneWidget); // B did not update
      expect(buildsA, greaterThan(initialBuildsA));
      expect(buildsB, equals(initialBuildsB)); // B was NOT rebuilt
    });

    testWidgets('ZenView with ID-targeted ZenUpdater inside', (tester) async {
      final ctrl = CountController();
      Zen.put<CountController>(ctrl);

      await tester.pumpWidget(
        const MaterialApp(home: IdUpdaterView()),
      );

      expect(find.text('a:0'), findsOneWidget);
      expect(find.text('b:0'), findsOneWidget);

      await tester.tap(find.text('inc-a'));
      await tester.pump();

      expect(find.text('a:1'), findsOneWidget);
      expect(find.text('b:0'), findsOneWidget); // b unchanged
    });
  });

  // ── 3. ZenScopeWidget.create controller disposal ─────────────────────────

  group('ZenScopeWidget.create disposal', () {
    testWidgets('disposes controller when widget leaves the tree',
        (tester) async {
      CountController? capturedCtrl;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget.create<CountController>(
            create: () {
              final c = CountController();
              capturedCtrl = c;
              return c;
            },
            child: Builder(
              builder: (ctx) => Text(
                  'val:${ctx.controller<CountController>().plainCount}'),
            ),
          ),
        ),
      );

      expect(capturedCtrl, isNotNull);
      expect(capturedCtrl!.disposed, isFalse);

      // Remove widget from tree
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(capturedCtrl!.disposed, isTrue);
    });

    testWidgets('controller is NOT in global scope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget.create<CountController>(
            create: CountController.new,
            child: Builder(
              builder: (ctx) {
                final c = ctx.controller<CountController>();
                return Text('count:${c.plainCount}');
              },
            ),
          ),
        ),
      );

      expect(find.text('count:0'), findsOneWidget);
      // Must NOT be registered in global DI
      expect(Zen.findOrNull<CountController>(), isNull);
    });
  });

  // ── 4. initController reactive .obs() rebuild ─────────────────────────────

  group('ZenView.initController reactive rebuild', () {
    testWidgets('ZenObserver inside owned view rebuilds on .obs() change',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ReactiveOwnedView()),
      );

      expect(find.text('reactive:0'), findsOneWidget);

      await tester.tap(find.text('inc'));
      await tester.pump();

      expect(find.text('reactive:1'), findsOneWidget);
    });

    testWidgets('two owned instances react independently', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              Flexible(child: ReactiveOwnedView(key: ValueKey('left'))),
              Flexible(child: ReactiveOwnedView(key: ValueKey('right'))),
            ],
          ),
        ),
      );

      expect(find.text('reactive:0'), findsNWidgets(2));

      // Tap the first view's button only
      await tester.tap(find.text('inc').first);
      await tester.pump();

      // Left became 1, right still 0
      expect(find.text('reactive:1'), findsOneWidget);
      expect(find.text('reactive:0'), findsOneWidget);
    });
  });

  // ── 5. ZenConsumer scope-bound (finds nearest, not always global) ─────────

  group('ZenConsumer scope binding', () {
    testWidgets('finds nearest scope controller over global', (tester) async {
      final global = CountController()..plainCount = 10;
      Zen.put<CountController>(global);

      CountController? receivedCtrl;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenScopeWidget.create<CountController>(
            create: () => CountController()..plainCount = 99,
            child: ZenConsumer<CountController>(
              builder: (ctx, ctrl) {
                receivedCtrl = ctrl;
                return Text('val:${ctrl.plainCount}');
              },
            ),
          ),
        ),
      );

      // Should get the scoped one (99), not the global (10)
      expect(find.text('val:99'), findsOneWidget);
      expect(receivedCtrl?.plainCount, 99);
      expect(receivedCtrl, isNot(same(global)));
    });

    testWidgets('falls back to global when not in a scope', (tester) async {
      final global = CountController()..plainCount = 42;
      Zen.put<CountController>(global);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenConsumer<CountController>(
            builder: (ctx, ctrl) => Text('val:${ctrl.plainCount}'),
          ),
        ),
      );

      expect(find.text('val:42'), findsOneWidget);
    });
  });
}
