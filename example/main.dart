import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Zen.init();

  // Simple environment-based configuration (RECOMMENDED)
  if (kReleaseMode) {
    ZenConfig.applyEnvironment(ZenEnvironment.production);
  } else {
    ZenConfig.applyEnvironment(ZenEnvironment.development);
  }

  // Or use fine-grained control
  ZenConfig.configure(
    level: kDebugMode ? ZenLogLevel.info : ZenLogLevel.warning,
    performanceTracking: kDebugMode,
    strict: kDebugMode,
  );

  runApp(const ZenifyExampleApp());
}

class ZenifyExampleApp extends StatelessWidget {
  const ZenifyExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Zenify Example',
      home: CounterPage(),
    );
  }
}

class CounterController extends ZenController {
  final count = 0.obs();

  void increment() => count.value++;
  void decrement() => count.value--;
}

class CounterPage extends ZenView<CounterController> {
  const CounterPage({super.key});

  @override
  CounterController Function()? get createController =>
      () => CounterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zenify Counter Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'You have pushed the button this many times:',
            ),
            Obx(() => Text(
                  '${controller.count.value}',
                  style: Theme.of(context).textTheme.headlineMedium,
                )),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: controller.decrement,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: controller.increment,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
