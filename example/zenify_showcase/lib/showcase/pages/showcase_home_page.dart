import 'package:flutter/material.dart';
import '../widgets/feature_card.dart';
import 'reactive_demo_page.dart';
import 'effect_demo_page.dart';
import 'worker_demo_page.dart';
import 'obx_demo_page.dart';
import 'zen_updater_demo_page.dart';
import 'package:zenify/zenify.dart';
import '../controllers/reactive_demo_controller.dart';
import '../controllers/effect_demo_controller.dart';
import '../controllers/worker_demo_controller.dart';
import '../controllers/zen_updater_demo_controller.dart';

class ShowcaseHomePage extends StatelessWidget {
  const ShowcaseHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Zenify Showcase',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.widgets,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildListDelegate([
                FeatureCard(
                  title: 'Reactive State',
                  subtitle: 'ZenObserver & Observable Values',
                  icon: Icons.refresh,
                  color: Colors.blue,
                  onTap: () => _navigateTo(
                      context,
                      ZenProvider.create(
                          create: () => ReactiveDemoController(),
                          child: const ReactiveDemoPage())),
                ),
                FeatureCard(
                  title: 'ZenEffects',
                  subtitle: 'Async State Management',
                  icon: Icons.bolt,
                  color: Colors.purple,
                  onTap: () => _navigateTo(
                      context,
                      ZenProvider.create(
                          create: () => EffectDemoController(),
                          child: const EffectDemoPage())),
                ),
                FeatureCard(
                  title: 'Workers',
                  subtitle: 'Reactive Side Effects',
                  icon: Icons.work,
                  color: Colors.teal,
                  onTap: () => _navigateTo(
                      context,
                      ZenProvider.create(
                          create: () => WorkerDemoController(),
                          child: const WorkerDemoPage())),
                ),
                FeatureCard(
                  title: 'ZenObserver Widget',
                  subtitle: 'Granular Reactivity',
                  icon: Icons.visibility,
                  color: Colors.orange,
                  onTap: () => _navigateTo(
                      context,
                      ZenProvider.create(
                          create: () => ReactiveDemoController(),
                          child: const ObxDemoPage())),
                ),
                FeatureCard(
                  title: 'ZenUpdater',
                  subtitle: 'Controller Integration',
                  icon: Icons.build,
                  color: Colors.green,
                  onTap: () => _navigateTo(
                      context,
                      ZenProvider.create(
                          create: () => ZenUpdaterDemoController(),
                          child: const ZenUpdaterDemoPage())),
                ),
                FeatureCard(
                  title: 'Performance',
                  subtitle: 'Metrics & Optimization',
                  icon: Icons.speed,
                  color: Colors.red,
                  onTap: () => _showPerformanceInfo(context),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  void _showPerformanceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Performance Features'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Minimal rebuilds with granular reactivity'),
            Text('• Automatic disposal and memory management'),
            Text('• Efficient worker scheduling'),
            Text('• Built-in performance metrics'),
            Text('• Smart dependency injection'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
