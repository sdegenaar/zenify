
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/effect_demo_controller.dart';
import '../widgets/demo_section.dart';

class EffectDemoPage extends ZenView<EffectDemoController> {
  const EffectDemoPage({super.key});

  @override
  EffectDemoController Function()? get createController => () => EffectDemoController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenEffect Demo'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Basic Effect Demo
            DemoSection(
              title: 'Basic ZenEffect',
              subtitle: 'Simple async operations with state management',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ZenEffectBuilder<String>(
                        effect: controller.basicEffect,
                        onInitial: () => _buildEffectState(
                          'Ready to Start',
                          'Click button to run effect',
                          Colors.blue,
                          Icons.play_arrow,
                        ),
                        onLoading: () => _buildEffectState(
                          'Loading...',
                          'Effect is running',
                          Colors.orange,
                          Icons.hourglass_empty,
                          showProgress: true,
                        ),
                        onSuccess: (data) => _buildEffectState(
                          'Success!',
                          'Result: $data',
                          Colors.green,
                          Icons.check_circle,
                        ),
                        onError: (error) => _buildEffectState(
                          'Error',
                          error.toString(),
                          Colors.red,
                          Icons.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.runBasicEffect,
                              child: const Text('Run Success'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.runBasicEffectWithError,
                              child: const Text('Run Error'),
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

            // Data Fetching Effect
            DemoSection(
              title: 'Data Fetching Effect',
              subtitle: 'Simulates API calls and data loading',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ZenEffectBuilder<List<String>>(
                        effect: controller.dataEffect,
                        onInitial: () => _buildDataState(
                          'No Data Loaded',
                          'Click to fetch data from API',
                          Colors.grey,
                          Icons.cloud_download,
                        ),
                        onLoading: () => _buildDataState(
                          'Fetching Data...',
                          'Loading from server',
                          Colors.orange,
                          Icons.sync,
                          showProgress: true,
                        ),
                        onSuccess: (data) => Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                border: Border.all(color: Colors.green.shade200),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green.shade700),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Data Loaded Successfully',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...data.map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.fiber_manual_record,
                                            size: 8, color: Colors.green.shade600),
                                        const SizedBox(width: 8),
                                        Text(item),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onError: (error) => _buildDataState(
                          'Failed to Load Data',
                          error.toString(),
                          Colors.red,
                          Icons.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.fetchData,
                              child: const Text('Fetch Data'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: controller.fetchDataWithError,
                              child: const Text('Simulate Error'),
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

            // Multiple Effects Demo
            DemoSection(
              title: 'Multiple Effects',
              subtitle: 'Managing multiple async operations',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Effect 1
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ZenEffectBuilder<String>(
                          effect: controller.effect1,
                          onInitial: () => _buildMiniEffectState('Effect 1', 'Ready', Colors.blue),
                          onLoading: () => _buildMiniEffectState('Effect 1', 'Running...', Colors.orange),
                          onSuccess: (data) => _buildMiniEffectState('Effect 1', 'Success: $data', Colors.green),
                          onError: (error) => _buildMiniEffectState('Effect 1', 'Error', Colors.red),
                        ),
                      ),

                      // Effect 2
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ZenEffectBuilder<String>(
                          effect: controller.effect2,
                          onInitial: () => _buildMiniEffectState('Effect 2', 'Ready', Colors.blue),
                          onLoading: () => _buildMiniEffectState('Effect 2', 'Running...', Colors.orange),
                          onSuccess: (data) => _buildMiniEffectState('Effect 2', 'Success: $data', Colors.green),
                          onError: (error) => _buildMiniEffectState('Effect 2', 'Error', Colors.red),
                        ),
                      ),

                      // Effect 3
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ZenEffectBuilder<String>(
                          effect: controller.effect3,
                          onInitial: () => _buildMiniEffectState('Effect 3', 'Ready', Colors.blue),
                          onLoading: () => _buildMiniEffectState('Effect 3', 'Running...', Colors.orange),
                          onSuccess: (data) => _buildMiniEffectState('Effect 3', 'Success: $data', Colors.green),
                          onError: (error) => _buildMiniEffectState('Effect 3', 'Error', Colors.red),
                        ),
                      ),

                      // Control buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: controller.runEffect1,
                            child: const Text('Run 1'),
                          ),
                          ElevatedButton(
                            onPressed: controller.runEffect2,
                            child: const Text('Run 2'),
                          ),
                          ElevatedButton(
                            onPressed: controller.runEffect3,
                            child: const Text('Run 3'),
                          ),
                          ElevatedButton(
                            onPressed: controller.runAllEffects,
                            child: const Text('Run All'),
                          ),
                          ElevatedButton(
                            onPressed: controller.resetAllEffects,
                            child: const Text('Reset All'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Effect State Monitoring
            DemoSection(
              title: 'Effect State Monitoring',
              subtitle: 'Real-time effect state information',
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStateMonitor('Basic Effect', controller.basicEffect),
                      const Divider(),
                      _buildStateMonitor('Data Effect', controller.dataEffect),
                      const Divider(),
                      _buildStateMonitor('Effect 1', controller.effect1),
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

  Widget _buildEffectState(
      String title,
      String message,
      Color color,
      IconData icon, {
        bool showProgress = false,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (showProgress)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataState(
      String title,
      String message,
      Color color,
      IconData icon, {
        bool showProgress = false,
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (showProgress)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            )
          else
            Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEffectState(String name, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
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
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            status,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }



  Widget _buildStateMonitor(String name, ZenEffect effect) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Obx(() => _buildStateIndicator('Loading', effect.isLoading.value, Colors.orange)),
          const SizedBox(width: 8),
          Obx(() => _buildStateIndicator('Success', effect.dataWasSet.value, Colors.green)),
          const SizedBox(width: 8),
          Obx(() => _buildStateIndicator('Error', effect.error.value != null, Colors.red)),
        ],
      ),
    );
  }

  Widget _buildStateIndicator(String label, bool active, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? color : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? color : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}