import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/worker_demo_controller.dart';
import '../widgets/demo_section.dart';

class WorkerDemoPage extends ZenView<WorkerDemoController> {
  const WorkerDemoPage({super.key});

  @override
  WorkerDemoController Function()? get createController => () => WorkerDemoController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workers Demo'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Counter Control Section
            DemoSection(
              title: 'Counter Control',
              subtitle: 'Use this to trigger different worker behaviors',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Obx(() => Text(
                        '${controller.counter.value}',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: controller.decrementCounter,
                            child: const Text('- 1'),
                          ),
                          ElevatedButton(
                            onPressed: controller.incrementCounter,
                            child: const Text('+ 1'),
                          ),
                          ElevatedButton(
                            onPressed: controller.rapidIncrement,
                            child: const Text('Rapid +5'),
                          ),
                          ElevatedButton(
                            onPressed: controller.resetCounter,
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Worker Statistics
            DemoSection(
              title: 'Worker Statistics',
              subtitle: 'See how different workers respond to changes',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Obx(() => _buildWorkerStats('Ever Worker',
                          controller.everCount.value,
                          'Fires on every change',
                          Colors.blue)),
                      const SizedBox(height: 12),
                      Obx(() => _buildWorkerStats('Debounce Worker',
                          controller.debounceCount.value,
                          'Waits 500ms after last change',
                          Colors.orange)),
                      const SizedBox(height: 12),
                      Obx(() => _buildWorkerStats('Throttle Worker',
                          controller.throttleCount.value,
                          'Max once per 1000ms',
                          Colors.purple)),
                      const SizedBox(height: 12),
                      Obx(() => _buildWorkerStats('Once Worker',
                          controller.onceCount.value,
                          'Fires only once then stops',
                          Colors.green)),
                      const SizedBox(height: 12),
                      Obx(() => _buildWorkerStats('Condition Worker',
                          controller.conditionCount.value,
                          'Only when counter is even',
                          Colors.red)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // String Worker Demo
            DemoSection(
              title: 'String Worker Demo',
              subtitle: 'Workers can observe any observable type',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Obx(() => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.text_fields, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controller.message.value,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.updateMessage,
                              child: const Text('Update Message'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.clearMessage,
                              child: const Text('Clear Message'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Obx(() => Text(
                        'String worker fired ${controller.stringWorkerCount.value} times',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // List Worker Demo
            DemoSection(
              title: 'List Worker Demo',
              subtitle: 'Workers observing collection changes',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Obx(() => Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.list, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Items (${controller.items.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (controller.items.isEmpty)
                              const Text('No items in the list')
                            else
                              ...controller.items.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.fiber_manual_record,
                                        size: 8, color: Colors.green.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(item)),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 16),
                                      onPressed: () => controller.removeItem(item),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              )),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
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
                              child: const Text('Clear All'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Obx(() => Text(
                        'List worker fired ${controller.listWorkerCount.value} times',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Worker Control Panel
            DemoSection(
              title: 'Worker Control Panel',
              subtitle: 'Manage worker lifecycles',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.pauseWorkers,
                              child: const Text('Pause Workers'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.resumeWorkers,
                              child: const Text('Resume Workers'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.resetAllCounters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reset All Counters'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          border: Border.all(color: Colors.amber.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Try the "Rapid +5" button to see the difference between ever, debounce, and throttle workers!',
                                style: TextStyle(color: Colors.amber.shade700),
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
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerStats(String name, int count, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}