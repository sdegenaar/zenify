import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/counter_controller.dart';

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZenControllerScope<CounterController>(
      create: () => CounterController(),
      child: Builder(
          builder: (context) {
            final controller = Zen.find<CounterController>()!;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Counter Example'),
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'You have pushed the button this many times:',
                    ),
                    // Obx automatically tracks and rebuilds when counter changes
                    Obx(() => Text(
                      '${controller.counter.value}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    )),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Decrement button
                        ElevatedButton(
                          onPressed: controller.decrement,
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 20),
                        // Reset button
                        ElevatedButton(
                          onPressed: controller.reset,
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          child: const Icon(Icons.refresh),
                        ),
                        const SizedBox(width: 20),
                        // Increment button
                        ElevatedButton(
                          onPressed: controller.increment,
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'Check the console for logs of counter changes\n'
                          'and special messages at multiples of 5',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
      ),
    );
  }
}