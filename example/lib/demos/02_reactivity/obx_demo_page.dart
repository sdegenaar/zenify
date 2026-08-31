import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import 'controllers/reactive_demo_controller.dart';
import '../../shared/widgets/demo_section.dart';
import '../../shared/widgets/showcase_style.dart';

class ObxDemoPage extends ZenView<ReactiveDemoController> {
  const ObxDemoPage({super.key});

  @override
  Widget build(BuildContext context, ReactiveDemoController controller) {
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
                              decoration: ShowcaseStyle.containerDecoration(
                                context,
                                color: Colors.blue,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Counter Section',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: ShowcaseStyle.accentHeader(
                                          context, Colors.blue),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ZenObserver(() => Text(
                                        '${controller.counter.value}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium
                                            ?.copyWith(
                                              color: ShowcaseStyle.accentHeader(
                                                  context, Colors.blue),
                                              fontWeight: FontWeight.bold,
                                            ),
                                      )),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Only rebuilds when counter changes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ShowcaseStyle.textMuted(context),
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
                              decoration: ShowcaseStyle.containerDecoration(
                                context,
                                color: Colors.green,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Message Section',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: ShowcaseStyle.accentHeader(
                                          context, Colors.green),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ZenObserver(() => Text(
                                        controller.message.value,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: ShowcaseStyle.accentHeader(
                                              context, Colors.green),
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      )),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Only rebuilds when message changes',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ShowcaseStyle.textMuted(context),
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
                              ZenObserver(() => Text(
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
                              ZenObserver(() => Icon(
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
              subtitle:
                  'See real-time rebuild counts for each ZenObserver widget',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Rebuild counters (live reactive tracking)
                      ZenObserver(() => Column(
                            children: [
                              _buildPerformanceMetric(
                                  context,
                                  'Counter ZenObserver Rebuilds',
                                  controller.counterRebuilds.value),
                              const SizedBox(height: 8),
                              _buildPerformanceMetric(
                                  context,
                                  'Message ZenObserver Rebuilds',
                                  controller.messageRebuilds.value),
                              const SizedBox(height: 8),
                              _buildPerformanceMetric(
                                  context,
                                  'Items ZenObserver Rebuilds',
                                  controller.itemsRebuilds.value),
                              const SizedBox(height: 8),
                              _buildPerformanceMetric(
                                  context,
                                  'Features ZenObserver Rebuilds',
                                  controller.featuresRebuilds.value),
                            ],
                          )),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.restart_alt, size: 16),
                          label: const Text('Reset Counters'),
                          onPressed: controller.resetRebuildCounters,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: ShowcaseStyle.containerDecoration(
                          context,
                          color: Colors.green,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.speed,
                                color: ShowcaseStyle.accentHeader(
                                    context, Colors.green)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ZenObserver provides granular reactivity - only widgets observing changed values rebuild!',
                                style: TextStyle(
                                  color: ShowcaseStyle.textPrimary(context),
                                  fontWeight: FontWeight.w500,
                                ),
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
                        decoration: ShowcaseStyle.containerDecoration(
                          context,
                          color: Colors.blue,
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
                                    color: ShowcaseStyle.accentHeader(
                                        context, Colors.blue),
                                  ),
                                ),
                                ZenObserver(() => Chip(
                                      label: Text(
                                        '${controller.items.length}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: ShowcaseStyle.accentHeader(
                                              context, Colors.blue),
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ZenObserver(
                              () => controller.items.isEmpty
                                  ? Text(
                                      'No items added yet',
                                      style: TextStyle(
                                        color: ShowcaseStyle.textMuted(context),
                                      ),
                                    )
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
                                                      color: ShowcaseStyle
                                                          .accentHeader(context,
                                                              Colors.blue)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      item,
                                                      style: TextStyle(
                                                        color: ShowcaseStyle
                                                            .textPrimary(
                                                                context),
                                                      ),
                                                    ),
                                                  ),
                                                  if (controller.items.length >
                                                          3 &&
                                                      item ==
                                                          controller
                                                              .items.value[2])
                                                    Text(
                                                      '+${controller.items.length - 3} more',
                                                      style: TextStyle(
                                                        color: ShowcaseStyle
                                                            .textMuted(context),
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
                                  context,
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
                            child: ZenObserver(() => _buildStatusIndicator(
                                  context,
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

  Widget _buildPerformanceMetric(
      BuildContext context, String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: ShowcaseStyle.textPrimary(context)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: ShowcaseStyle.containerDecoration(
            context,
            color: Colors.blue,
            radius: 12,
          ),
          child: Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ShowcaseStyle.accentHeader(context, Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(
      BuildContext context, String title, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: ShowcaseStyle.containerDecoration(
        context,
        color: color,
        radius: 6,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: ShowcaseStyle.accentHeader(context, color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ShowcaseStyle.accentHeader(context, color),
            ),
          ),
        ],
      ),
    );
  }
}
