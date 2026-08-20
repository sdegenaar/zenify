/// Zenify — pub.dev minimal usage example.
///
/// Canonical 3-step reactive pipeline: [ZenController] → [ZenModule] → [ZenView].
/// Demonstrates [ZenProvider] scope injection and fine-grained [ZenObserver] reactivity.
///
/// Run this minimal example:
///   cd example && flutter run -t example.dart
///
/// Run the full interactive showcase (7 demo suites):
///   cd example && flutter run

library;

import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Controller — state & logic with auto-cleanup
// ─────────────────────────────────────────────────────────────────────────────

class CounterController extends ZenController {
  final count = 0
      .obs(); // reactive — any ZenObserver watching this rebuilds automatically

  void increment() => count.value++;
  void decrement() => count.value = (count.value - 1).clamp(0, 999);
  void reset() => count.value = 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Module — encapsulates dependency injection in a scoped container
// ─────────────────────────────────────────────────────────────────────────────

class CounterModule extends ZenModule {
  @override
  String get name => 'CounterModule';

  @override
  void register(ZenScope scope) {
    scope.put<CounterController>(CounterController());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: View — auto-resolves controller from scope, reactive with ZenObserver
// ─────────────────────────────────────────────────────────────────────────────

class CounterPage extends ZenView<CounterController> {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context, CounterController controller) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zenify Counter Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: controller.reset,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Reactive Counter',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            // ZenObserver rebuilds automatically whenever count.value changes
            ZenObserver(() => Text(
                  '${controller.count.value}',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: controller.decrement,
                  icon: const Icon(Icons.remove),
                  label: const Text('Decrement'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: controller.increment,
                  icon: const Icon(Icons.add),
                  label: const Text('Increment'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bootstrap
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Zen.init();

  runApp(const CounterExampleApp());
}

class CounterExampleApp extends StatelessWidget {
  const CounterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenify Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      // ZenProvider provides CounterModule dependencies to child widgets
      home: ZenProvider(
        moduleBuilder: () => CounterModule(),
        child: const CounterPage(),
      ),
    );
  }
}
