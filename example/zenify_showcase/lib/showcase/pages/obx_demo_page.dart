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
        title: const Text('ZenObserver Granular Reactivity'),
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
                  'Only specific ZenObserver widgets rebuild when their observed values change',
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
                                  ZenObserver(() => Text(
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
                                  ZenObserver(() => Text(
                                        Zen.find<ReactiveDemoController>()
                                            .message
                                            .value,
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
                              onPressed:
                                  Zen.find<ReactiveDemoController>().increment,
                              child: const Text('+ Counter'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: Zen.find<ReactiveDemoController>()
                                  .updateMessage,
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

            // Multiple ZenObserver Demo
            DemoSection(
              title: 'Multiple Independent ZenObserver Widgets',
              subtitle:
                  'Each ZenObserver only observes specific reactive values',
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
                              ZenObserver(() => Text(
                                    '${Zen.find<ReactiveDemoController>().counter.value}',
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
                              ZenObserver(() => Text(
                                    '${Zen.find<ReactiveDemoController>().items.length}',
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
                              ZenObserver(() => Icon(
                                    Zen.find<ReactiveDemoController>()
                                            .bothFeaturesEnabled
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
                            onPressed:
                                Zen.find<ReactiveDemoController>().increment,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('+ Counter',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed:
                                Zen.find<ReactiveDemoController>().addItem,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple),
                            child: const Text('+ Item',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () => Zen.find<ReactiveDemoController>()
                                .featureA
                                .toggle(),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal),
                            child: const Text('Toggle A',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () => Zen.find<ReactiveDemoController>()
                                .featureB
                                .toggle(),
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
              subtitle: 'See rebuild counts for each ZenObserver widget',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Rebuild counters (simulated)
                      _buildPerformanceMetric('Counter ZenObserver Rebuilds',
                          _getCounterRebuilds()),
                      const SizedBox(height: 8),
                      _buildPerformanceMetric('Message ZenObserver Rebuilds',
                          _getMessageRebuilds()),
                      const SizedBox(height: 8),
                      _buildPerformanceMetric(
                          'Items ZenObserver Rebuilds', _getItemsRebuilds()),
                      const SizedBox(height: 8),
                      _buildPerformanceMetric('Features ZenObserver Rebuilds',
                          _getFeaturesRebuilds()),

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
                                'ZenObserver provides granular reactivity - only widgets observing changed values rebuild!',
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

            // Complex ZenObserver Demo
            DemoSection(
              title: 'Complex Reactive UI',
              subtitle: 'Multiple ZenObserver widgets working together',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Dynamic list with ZenObserver
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
                                ZenObserver(() => Chip(
                                      label: Text(
                                          '${Zen.find<ReactiveDemoController>().items.length}'),
                                      backgroundColor: Colors.blue.shade200,
                                    )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ZenObserver(
                              () => Zen.find<ReactiveDemoController>()
                                      .items
                                      .isEmpty
                                  ? const Text('No items added yet')
                                  : Column(
                                      children: Zen.find<
                                              ReactiveDemoController>()
                                          .items
                                          .value
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
                                                  if (Zen.find<ReactiveDemoController>()
                                                              .items
                                                              .length >
                                                          3 &&
                                                      item ==
                                                          Zen.find<
                                                                  ReactiveDemoController>()
                                                              .items
                                                              .value[2])
                                                    Text(
                                                      '+${Zen.find<ReactiveDemoController>().items.length - 3} more',
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
                            child: ZenObserver(() => _buildStatusIndicator(
                                  'Counter Status',
                                  Zen.find<ReactiveDemoController>()
                                              .counter
                                              .value >
                                          0
                                      ? 'Active'
                                      : 'Zero',
                                  Zen.find<ReactiveDemoController>()
                                              .counter
                                              .value >
                                          0
                                      ? Colors.green
                                      : Colors.grey,
                                )),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ZenObserver(() => _buildStatusIndicator(
                                  'Features Status',
                                  Zen.find<ReactiveDemoController>()
                                          .bothFeaturesEnabled
                                      ? 'Enabled'
                                      : 'Disabled',
                                  Zen.find<ReactiveDemoController>()
                                          .bothFeaturesEnabled
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
