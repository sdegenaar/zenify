import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/zen_builder_demo_controller.dart'; // Changed import
import '../widgets/demo_section.dart';

class ZenBuilderDemoPage extends ZenView<ZenBuilderDemoController> {
  // Changed controller type
  const ZenBuilderDemoPage({super.key});

  @override
  ZenBuilderDemoController Function()? get createController =>
      () => ZenBuilderDemoController(); // Changed controller

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenBuilder Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Basic ZenBuilder
            DemoSection(
              title: 'Basic ZenBuilder',
              subtitle: 'Manual state management with update() calls',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ZenBuilder<ZenBuilderDemoController>(
                        builder: (context, controller) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              border: Border.all(color: Colors.green.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'ZenBuilder Content',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Counter: ${controller.counter}'), // No .value needed
                                Text(
                                    'Message: ${controller.message}'), // No .value needed
                                Text(
                                    'Items: ${controller.items.length}'), // No .value needed
                                const SizedBox(height: 8),
                                Text(
                                  'Built at: ${DateTime.now().toString().split('.').first}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
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

            // Multiple ZenBuilders
            DemoSection(
              title: 'Multiple ZenBuilders',
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
                            child: ZenBuilder<ZenBuilderDemoController>(
                              builder: (context, controller) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Builder 1',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${controller.counter}', // No .value needed
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const Text('Counter Focus'),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Builder 2 - Message focused
                          Expanded(
                            child: ZenBuilder<ZenBuilderDemoController>(
                              builder: (context, controller) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    border: Border.all(
                                        color: Colors.purple.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Builder 2',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        controller.message, // No .value needed
                                        style: TextStyle(
                                          color: Colors.purple,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const Text('Message Focus'),
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
                      ZenBuilder<ZenBuilderDemoController>(
                        builder: (context, controller) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Builder 3 - Complete State',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                    'Counter: ${controller.counter}'), // No .value needed
                                Text(
                                    'Message: "${controller.message}"'), // No .value needed
                                Text(
                                    'Items: ${controller.items.length}'), // No .value needed
                                Text(
                                    'Feature A: ${controller.featureA}'), // No .value needed
                                Text(
                                    'Feature B: ${controller.featureB}'), // No .value needed
                                Text(
                                    'Both Enabled: ${controller.bothFeaturesEnabled}'),
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
              title: 'ZenBuilder Actions',
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
