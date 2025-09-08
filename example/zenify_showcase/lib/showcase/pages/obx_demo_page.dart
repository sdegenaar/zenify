import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/reactive_demo_controller.dart';
import '../widgets/demo_section.dart';

class ObxDemoPage extends ZenView<ReactiveDemoController> {
  const ObxDemoPage({super.key});

  @override
  ReactiveDemoController Function()? get createController =>
      () => ReactiveDemoController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obx Granular Reactivity'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Granular Updates Demo
            DemoSection(
              title: 'Granular Updates',
              subtitle:
                  'Only specific Obx widgets rebuild when their observed values change',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Counter section - only rebuilds when counter changes
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                border: Border.all(color: Colors.blue.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Counter Section',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Obx(() => Text(
                                        '${controller.counter.value}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      )),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Only rebuilds when counter changes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Message section - only rebuilds when message changes
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                border:
                                    Border.all(color: Colors.green.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Message Section',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Obx(() => Text(
                                        controller.message.value,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      )),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Only rebuilds when message changes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Control buttons
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

            // Multiple Obx Demo
            DemoSection(
              title: 'Multiple Independent Obx Widgets',
              subtitle: 'Each Obx only observes specific reactive values',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Three independent sections
                      Row(
                        children: [
                          Expanded(
                            child: _buildObxSection(
                              'Counter',
                              Colors.red,
                              Obx(() => Text(
                                    '${controller.counter.value}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildObxSection(
                              'Items Count',
                              Colors.purple,
                              Obx(() => Text(
                                    '${controller.items.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  )),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildObxSection(
                              'Features',
                              Colors.teal,
                              Obx(() => Icon(
                                    controller.bothFeaturesEnabled
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: Colors.white,
                                    size: 24,
                                  )),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Control buttons for each section
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: controller.increment,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('+ Counter',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: controller.addItem,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple),
                            child: const Text('+ Item',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () => controller.featureA.toggle(),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal),
                            child: const Text('Toggle A',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () => controller.featureB.toggle(),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal),
                            child: const Text('Toggle B',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Performance Comparison
            DemoSection(
              title: 'Performance Visualization',
              subtitle: 'See rebuild counts for each Obx widget',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Rebuild counters (simulated)
                      _buildPerformanceMetric(
                          'Counter Obx Rebuilds', _getCounterRebuilds()),
                      const SizedBox(height: 8),
                      _buildPerformanceMetric(
                          'Message Obx Rebuilds', _getMessageRebuilds()),
                      const SizedBox(height: 8),
                      _buildPerformanceMetric(
                          'Items Obx Rebuilds', _getItemsRebuilds()),
                      const SizedBox(height: 8),
                      _buildPerformanceMetric(
                          'Features Obx Rebuilds', _getFeaturesRebuilds()),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.speed, color: Colors.green.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Obx provides granular reactivity - only widgets observing changed values rebuild!',
                                style: TextStyle(color: Colors.green.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Complex Obx Demo
            DemoSection(
              title: 'Complex Reactive UI',
              subtitle: 'Multiple Obx widgets working together',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Dynamic list with Obx
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Dynamic Item List',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                Obx(() => Chip(
                                      label: Text('${controller.items.length}'),
                                      backgroundColor: Colors.blue.shade200,
                                    )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Obx(
                              () => controller.items.isEmpty
                                  ? const Text('No items added yet')
                                  : Column(
                                      children: controller.items.value
                                          .take(3)
                                          .map(
                                            (item) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.circle,
                                                      size: 8,
                                                      color:
                                                          Colors.blue.shade600),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(item)),
                                                  if (controller.items.length >
                                                          3 &&
                                                      item ==
                                                          controller
                                                              .items.value[2])
                                                    Text(
                                                      '+${controller.items.length - 3} more',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey.shade600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Status indicators
                      Row(
                        children: [
                          Expanded(
                            child: Obx(() => _buildStatusIndicator(
                                  'Counter Status',
                                  controller.counter.value > 0
                                      ? 'Active'
                                      : 'Zero',
                                  controller.counter.value > 0
                                      ? Colors.green
                                      : Colors.grey,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Obx(() => _buildStatusIndicator(
                                  'Features Status',
                                  controller.bothFeaturesEnabled
                                      ? 'Enabled'
                                      : 'Disabled',
                                  controller.bothFeaturesEnabled
                                      ? Colors.green
                                      : Colors.orange,
                                )),
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

  Widget _buildObxSection(String title, Color color, Widget content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(String title, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Simulated rebuild counters (in real app, these would be tracked)
  int _getCounterRebuilds() => controller.counter.value; // Approximate
  int _getMessageRebuilds() => 5; // Simulated
  int _getItemsRebuilds() => controller.items.length;
  int _getFeaturesRebuilds() =>
      (controller.featureA.value ? 1 : 0) + (controller.featureB.value ? 1 : 0);
}
