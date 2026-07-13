import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Register — set up a feature module
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
// Step 2: Controller — all state lives here, auto-disposed on module teardown
// ─────────────────────────────────────────────────────────────────────────────

class CounterController extends ZenController {
  // Reactive state — auto-tracked, no manual dispose needed
  final RxInt count = 0.obs();
  final RxString status = 'Ready'.obs();

  // Manual-update state (for ZenUpdater demo)
  int manualCount = 0;

  @override
  void onInit() {
    super.onInit();
    // Workers run automatically and are auto-disposed with the controller
    ever(count, (val) {
      if (val >= 10) {
        status.value = '🔥 On fire!';
      } else if (val >= 5) {
        status.value = '⚡ Getting there...';
      } else {
        status.value = 'Ready';
      }
    });
  }

  void increment() => count.value++;
  void decrement() => count.value = (count.value - 1).clamp(0, 999);
  void reset() {
    count.value = 0;
    manualCount = 0;
    update(); // notify ZenUpdater widgets
  }

  void incrementManual() {
    manualCount++;
    update(); // only ZenUpdater rebuilds, not ZenObserver
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bootstrap
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Zen.init();
  runApp(const CounterApp());
}

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenify Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      // ZenScopeWidget provides CounterModule to the entire page
      home: ZenScopeWidget(
        moduleBuilder: () => CounterModule(),
        child: const CounterPage(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Consume — ZenView resolves the controller automatically
// ─────────────────────────────────────────────────────────────────────────────

class CounterPage extends ZenView<CounterController> {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context, CounterController controller) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zenify Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
            onPressed: controller.reset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── ZenObserver: rebuilds automatically on .obs() change ──────────
          _Section(
            title: 'ZenObserver',
            subtitle: 'Rebuilds automatically when count.value changes',
            child: Column(
              children: [
                ZenObserver(() => Text(
                  '${controller.count.value}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                const SizedBox(height: 8),
                ZenObserver(() => Chip(
                  label: Text(controller.status.value),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                )),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
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

          const SizedBox(height: 16),

          // ── ZenUpdater: only rebuilds on explicit update() call ───────────
          _Section(
            title: 'ZenUpdater',
            subtitle:
                'Only rebuilds when controller.update() is called explicitly',
            child: Column(
              children: [
                ZenUpdater<CounterController>(
                  builder: (ctx, ctrl) => Text(
                    '${ctrl.manualCount}',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: controller.incrementManual,
                  child: const Text('Manual Increment'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try incrementing — the ZenObserver counter above does NOT rebuild.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Concept summary ───────────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _Bullet(
                      'CounterModule registers CounterController into a ZenScope'),
                  const _Bullet(
                      'ZenScopeWidget provides that scope to the widget tree'),
                  const _Bullet(
                      'ZenView<CounterController> resolves it automatically — zero lookup code'),
                  const _Bullet(
                      'ZenObserver rebuilds on .obs() changes — fine-grained reactivity'),
                  const _Bullet(
                      'ZenUpdater rebuilds only on explicit update() — performance control'),
                  const _Bullet(
                      'Controller auto-disposes when the scope leaves the tree'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
