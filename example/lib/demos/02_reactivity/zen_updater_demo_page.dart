import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import 'controllers/zen_updater_demo_controller.dart';
import '../../shared/widgets/demo_section.dart';
import '../../shared/widgets/showcase_style.dart';

class ZenUpdaterDemoPage extends ZenView<ZenUpdaterDemoController> {
  // Changed controller type
  const ZenUpdaterDemoPage({super.key});

  // Changed controller

  @override
  Widget build(BuildContext context, ZenUpdaterDemoController controller) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenUpdater Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Basic ZenUpdater
            DemoSection(
              title: 'Basic ZenUpdater',
              subtitle: 'Manual state management with update() calls',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ZenUpdater<ZenUpdaterDemoController>(
                        builder: (context, controller) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: ShowcaseStyle.containerDecoration(
                              context,
                              color: Colors.green,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ZenUpdater Content',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ShowcaseStyle.accentHeader(
                                        context, Colors.green),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Counter: ${controller.counter}',
                                  style: TextStyle(
                                      color:
                                          ShowcaseStyle.textPrimary(context)),
                                ),
                                Text(
                                  'Message: ${controller.message}',
                                  style: TextStyle(
                                      color:
                                          ShowcaseStyle.textPrimary(context)),
                                ),
                                Text(
                                  'Items: ${controller.items.length}',
                                  style: TextStyle(
                                      color:
                                          ShowcaseStyle.textPrimary(context)),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Built at: ${DateTime.now().toString().split('.').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ShowcaseStyle.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.increment,
                              child: const Text('+ Counter'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.updateMessage,
                              child: const Text('Update Message'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Multiple ZenUpdaters
            DemoSection(
              title: 'Multiple ZenUpdaters',
              subtitle: 'Multiple builders observing the same controller',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Builder 1 - Counter focused
                          Expanded(
                            child: ZenUpdater<ZenUpdaterDemoController>(
                              builder: (context, controller) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: ShowcaseStyle.containerDecoration(
                                    context,
                                    color: Colors.blue,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Builder 1',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ShowcaseStyle.accentHeader(
                                              context, Colors.blue),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${controller.counter}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: ShowcaseStyle.accentHeader(
                                                  context, Colors.blue),
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        'Counter Focus',
                                        style: TextStyle(
                                          color:
                                              ShowcaseStyle.textMuted(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Builder 2 - Message focused
                          Expanded(
                            child: ZenUpdater<ZenUpdaterDemoController>(
                              builder: (context, controller) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: ShowcaseStyle.containerDecoration(
                                    context,
                                    color: Colors.purple,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Builder 2',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ShowcaseStyle.accentHeader(
                                              context, Colors.purple),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        controller.message,
                                        style: TextStyle(
                                          color: ShowcaseStyle.accentHeader(
                                              context, Colors.purple),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        'Message Focus',
                                        style: TextStyle(
                                          color:
                                              ShowcaseStyle.textMuted(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Builder 3 - Full state
                      ZenUpdater<ZenUpdaterDemoController>(
                        builder: (context, controller) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: ShowcaseStyle.containerDecoration(
                              context,
                              color: Colors.orange,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Builder 3 - Complete State',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ShowcaseStyle.accentHeader(
                                        context, Colors.orange),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Counter: ${controller.counter}',
                                    style: TextStyle(
                                        color: ShowcaseStyle.textPrimary(
                                            context))),
                                Text('Message: "${controller.message}"',
                                    style: TextStyle(
                                        color: ShowcaseStyle.textPrimary(
                                            context))),
                                Text('Items: ${controller.items.length}',
                                    style: TextStyle(
                                        color: ShowcaseStyle.textPrimary(
                                            context))),
                                Text('Feature A: ${controller.featureA}',
                                    style: TextStyle(
                                        color: ShowcaseStyle.textPrimary(
                                            context))),
                                Text('Feature B: ${controller.featureB}',
                                    style: TextStyle(
                                        color: ShowcaseStyle.textPrimary(
                                            context))),
                                Text(
                                    'Both Enabled: ${controller.bothFeaturesEnabled}',
                                    style: TextStyle(
                                        color: ShowcaseStyle.textPrimary(
                                            context))),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            DemoSection(
              title: 'ZenUpdater Actions',
              subtitle: 'Various ways to trigger updates',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Basic actions
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.increment,
                              child: const Text('Increment'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.decrement,
                              child: const Text('Decrement'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.reset,
                              child: const Text('Reset'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // List actions
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.addItem,
                              child: const Text('Add Item'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.clearItems,
                              child: const Text('Clear Items'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Feature toggles
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.toggleFeatureA,
                              child: const Text('Toggle A'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.toggleFeatureB,
                              child: const Text('Toggle B'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Advanced actions
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.incrementAndUpdateMessage,
                              child: const Text('Batch Update'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.resetAll,
                              child: const Text('Reset All'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
