import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/reactive_demo_controller.dart';
import '../widgets/demo_section.dart';
import '../widgets/showcase_style.dart';

class ReactiveDemoPage extends ZenView<ReactiveDemoController> {
  const ReactiveDemoPage({super.key});

  @override
  Widget build(BuildContext context, ReactiveDemoController controller) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reactive State Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Basic Reactive State
            DemoSection(
              title: 'Basic Reactive Values',
              child: Column(
                children: [
                  // Counter with ZenObserver
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Counter Example',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ZenObserver(() => Text(
                                '${controller.counter.value}',
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                              )),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: controller.decrement,
                                child: const Text('-'),
                              ),
                              ElevatedButton(
                                onPressed: controller.increment,
                                child: const Text('+'),
                              ),
                              ElevatedButton(
                                onPressed: controller.reset,
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text reactive state
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Text Example',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ZenObserver(() => Container(
                                padding: const EdgeInsets.all(12),
                                decoration: ShowcaseStyle.containerDecoration(
                                  context,
                                  color: Colors.blue,
                                ),
                                child: Text(
                                  controller.message.value,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: ShowcaseStyle.textPrimary(context),
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: controller.updateMessage,
                            child: const Text('Update Message'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Complex Reactive State
            DemoSection(
              title: 'Complex Reactive State',
              child: Column(
                children: [
                  // List example
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Reactive List',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ZenObserver(() => Column(
                                children: controller.items
                                    .map(
                                      (item) => Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            child: Text(
                                                '${controller.items.value.indexOf(item) + 1}'),
                                          ),
                                          title: Text(item),
                                          trailing: IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () =>
                                                controller.removeItem(item),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Boolean states
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Boolean States',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ZenObserver(() => SwitchListTile(
                                title: const Text('Feature A'),
                                value: controller.featureA.value,
                                onChanged: (value) =>
                                    controller.featureA.value = value,
                              )),
                          ZenObserver(() => SwitchListTile(
                                title: const Text('Feature B'),
                                value: controller.featureB.value,
                                onChanged: (value) =>
                                    controller.featureB.value = value,
                              )),
                          const SizedBox(height: 16),
                          ZenObserver(() {
                            final isEnabled = controller.bothFeaturesEnabled;
                            final color =
                                isEnabled ? Colors.green : Colors.grey;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: ShowcaseStyle.containerDecoration(
                                context,
                                color: color,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isEnabled
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: ShowcaseStyle.accentHeader(
                                        context, color),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isEnabled
                                          ? 'Both features enabled!'
                                          : 'Enable both features to unlock premium mode',
                                      style: TextStyle(
                                        color:
                                            ShowcaseStyle.textPrimary(context),
                                        fontWeight: isEnabled
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
