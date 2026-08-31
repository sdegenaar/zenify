import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import 'controllers/worker_demo_controller.dart';
import '../../shared/widgets/demo_section.dart';
import '../../shared/widgets/showcase_style.dart';

class WorkerDemoPage extends ZenView<WorkerDemoController> {
  const WorkerDemoPage({super.key});

  @override
  Widget build(BuildContext context, WorkerDemoController controller) {
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
            // Concept Explanation Header
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: ShowcaseStyle.containerDecoration(
                context,
                color: Colors.teal,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub_outlined,
                          color:
                              ShowcaseStyle.accentHeader(context, Colors.teal),
                          size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'What are ZenWorkers?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              ShowcaseStyle.accentHeader(context, Colors.teal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ZenWorkers (ever, debounce, throttle, once, interval) run background side-effects — like auto-saving, analytics, or search queries — in response to state changes, distinct from direct UI rendering (ZenObserver).',
                    style: TextStyle(
                      fontSize: 13,
                      color: ShowcaseStyle.textPrimary(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black26
                          : Colors.teal.shade50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 16,
                            color: ShowcaseStyle.accentHeader(
                                context, Colors.teal)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Try: Tap "Rapid +5" to compare worker timings, then tap "Pause All" to see side-effects muted while state continues updating!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: ShowcaseStyle.accentHeader(
                                  context, Colors.teal),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Counter Control Section
            DemoSection(
              title: 'Counter State & Triggers',
              subtitle:
                  'Mutating this state triggers the background workers below',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ZenObserver(() => Text(
                            '${controller.counter.value}',
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                          )),
                      const SizedBox(height: 8),
                      // Live Worker Status Pill
                      ZenObserver(() {
                        final isPaused = controller.isPaused.value;
                        final color = isPaused ? Colors.orange : Colors.green;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: ShowcaseStyle.containerDecoration(
                            context,
                            color: color,
                            radius: 20,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaused
                                    ? Icons.pause_circle_filled
                                    : Icons.check_circle,
                                size: 14,
                                color:
                                    ShowcaseStyle.accentHeader(context, color),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPaused
                                    ? 'Workers Paused (Side-effects muted)'
                                    : 'Workers Listening (Side-effects active)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: ShowcaseStyle.accentHeader(
                                      context, color),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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
                      // Live status banner
                      ZenObserver(() {
                        final isPaused = controller.isPaused.value;
                        final color = isPaused ? Colors.amber : Colors.green;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: ShowcaseStyle.containerDecoration(
                            context,
                            color: color,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPaused
                                    ? Icons.pause_circle
                                    : Icons.check_circle,
                                size: 18,
                                color:
                                    ShowcaseStyle.accentHeader(context, color),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isPaused
                                      ? 'Workers are PAUSED — state changes will not update counters below'
                                      : 'Workers are ACTIVE — listening to state changes in real time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ShowcaseStyle.accentHeader(
                                        context, color),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      ZenObserver(() => _buildWorkerStats(
                          context,
                          'Ever Worker',
                          controller.everCount.value,
                          'Fires on every change',
                          Colors.blue)),
                      const SizedBox(height: 12),
                      ZenObserver(() => _buildWorkerStats(
                          context,
                          'Debounce Worker',
                          controller.debounceCount.value,
                          'Waits 500ms after last change',
                          Colors.orange)),
                      const SizedBox(height: 12),
                      ZenObserver(() => _buildWorkerStats(
                          context,
                          'Throttle Worker',
                          controller.throttleCount.value,
                          'Max once per 1000ms',
                          Colors.purple)),
                      const SizedBox(height: 12),
                      ZenObserver(() => _buildWorkerStats(
                          context,
                          'Once Worker',
                          controller.onceCount.value,
                          'Fires only once then stops',
                          Colors.green)),
                      const SizedBox(height: 12),
                      ZenObserver(() => _buildWorkerStats(
                          context,
                          'Condition Worker',
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
                      ZenObserver(() => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: ShowcaseStyle.containerDecoration(
                              context,
                              color: Colors.blue,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.text_fields,
                                    color: ShowcaseStyle.accentHeader(
                                        context, Colors.blue)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    controller.message.value,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: ShowcaseStyle.textPrimary(context),
                                    ),
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
                      ZenObserver(() => Text(
                            'String worker fired ${controller.stringWorkerCount.value} times',
                            style: TextStyle(
                              color: ShowcaseStyle.textMuted(context),
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
                      ZenObserver(() => Container(
                            padding: const EdgeInsets.all(12),
                            decoration: ShowcaseStyle.containerDecoration(
                              context,
                              color: Colors.green,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.list,
                                        color: ShowcaseStyle.accentHeader(
                                            context, Colors.green)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Items (${controller.items.length})',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: ShowcaseStyle.accentHeader(
                                            context, Colors.green),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (controller.items.isEmpty)
                                  Text(
                                    'No items in the list',
                                    style: TextStyle(
                                      color: ShowcaseStyle.textMuted(context),
                                    ),
                                  )
                                else
                                  ...controller.items.map((item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          children: [
                                            Icon(Icons.fiber_manual_record,
                                                size: 8,
                                                color:
                                                    ShowcaseStyle.accentHeader(
                                                        context, Colors.green)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                item,
                                                style: TextStyle(
                                                  color:
                                                      ShowcaseStyle.textPrimary(
                                                          context),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 16),
                                              onPressed: () =>
                                                  controller.removeItem(item),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
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
                      ZenObserver(() => Text(
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
              subtitle: 'Batch manage worker lifecycles with ZenController',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active/Paused Status Banner
                      ZenObserver(() {
                        final isPaused = controller.isPaused.value;
                        final color = isPaused ? Colors.orange : Colors.green;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: ShowcaseStyle.containerDecoration(
                            context,
                            color: color,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPaused
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_filled,
                                size: 28,
                                color:
                                    ShowcaseStyle.accentHeader(context, color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isPaused
                                          ? 'Workers are PAUSED'
                                          : 'Workers are ACTIVE',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: ShowcaseStyle.accentHeader(
                                            context, color),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isPaused
                                          ? 'State changes are ignored by workers. Tap "Resume" to reactivate.'
                                          : 'Workers are tracking counter, message, and list mutations.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ShowcaseStyle.textMuted(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 16),

                      // Pause / Resume Toggle Buttons
                      ZenObserver(() {
                        final isPaused = controller.isPaused.value;
                        return Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.pause),
                                label: const Text('Pause All'),
                                onPressed: isPaused
                                    ? null
                                    : controller.pauseAllWorkers,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isPaused ? null : Colors.orange,
                                  foregroundColor:
                                      isPaused ? null : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Resume All'),
                                onPressed: isPaused
                                    ? controller.resumeAllWorkers
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      isPaused ? Colors.green : null,
                                  foregroundColor:
                                      isPaused ? Colors.white : null,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: const Text('Reset All Statistic Counters'),
                          onPressed: controller.resetAllCounters,
                        ),
                      ),

                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: ShowcaseStyle.containerDecoration(
                          context,
                          color: Colors.teal,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                color: ShowcaseStyle.accentHeader(
                                    context, Colors.teal)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ZenController automatically groups all workers registered in onInit(), allowing batch operations like pauseAllWorkers() and resumeAllWorkers().',
                                style: TextStyle(
                                  color: ShowcaseStyle.textPrimary(context),
                                  fontSize: 12,
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
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerStats(BuildContext context, String name, int count,
      String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShowcaseStyle.containerDecoration(
        context,
        color: color,
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
                    color: ShowcaseStyle.accentHeader(context, color),
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: ShowcaseStyle.textMuted(context),
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
