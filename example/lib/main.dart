import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

// Demos
import 'demos/01_counter/counter_demo.dart';
import 'demos/02_reactivity/controllers/reactive_demo_controller.dart';
import 'demos/02_reactivity/controllers/worker_demo_controller.dart';
import 'demos/02_reactivity/controllers/zen_updater_demo_controller.dart';
import 'demos/02_reactivity/obx_demo_page.dart';
import 'demos/02_reactivity/reactive_demo_page.dart';
import 'demos/02_reactivity/worker_demo_page.dart';
import 'demos/02_reactivity/zen_updater_demo_page.dart';
import 'demos/03_effects/controllers/effect_demo_controller.dart';
import 'demos/03_effects/effect_demo_page.dart';
import 'demos/04_scopes_and_di/flat/main.dart';
import 'demos/04_scopes_and_di/nested/main.dart';
import 'demos/05_zen_query/main.dart';
import 'demos/05_zen_query/modules/zen_query_module.dart';
import 'demos/06_offline_and_sync/feed_controller.dart';
import 'demos/06_offline_and_sync/main.dart';
import 'demos/06_offline_and_sync/storage.dart';
import 'demos/07_case_studies/ecommerce_app/main.dart';
import 'demos/07_case_studies/ecommerce_app/ecommerce/modules/app_module.dart'
    as ecommerce;
import 'demos/07_case_studies/todo_app/todo/controllers/todo_controller.dart';
import 'demos/07_case_studies/todo_app/todo/modules/todo_module.dart';
import 'demos/07_case_studies/todo_app/todo/pages/todo_home_page.dart';

// Shared
import 'shared/services/demo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Zenify with DevTools and Offline Storage support
  await Zen.init(
    registerDevTools: true,
    storage: SharedPreferencesStorage(),
  );

  // 2. Configure environment
  if (kReleaseMode) {
    ZenConfig.applyEnvironment(ZenEnvironment.production);
  } else {
    ZenConfig.applyEnvironment(ZenEnvironment.development);
  }

  // 3. Register shared modules
  Zen.put<DemoService>(DemoService());
  await Zen.registerModules([
    TodoModule(),
    ZenQueryModule(),
    ecommerce.AppModule(),
  ]);

  runApp(const ZenifyShowcaseApp());
}

class ZenifyShowcaseApp extends StatefulWidget {
  const ZenifyShowcaseApp({super.key});

  @override
  State<ZenifyShowcaseApp> createState() => _ZenifyShowcaseAppState();
}

class _ZenifyShowcaseAppState extends State<ZenifyShowcaseApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenify Demos & Showcase',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
        useMaterial3: true,
        brightness: Brightness.light,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6366F1),
        useMaterial3: true,
        brightness: Brightness.dark,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade800),
          ),
        ),
      ),
      home: ShowcaseCatalogScreen(
        onToggleTheme: _toggleTheme,
        isDark: _themeMode == ThemeMode.dark ||
            (_themeMode == ThemeMode.system &&
                WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                    Brightness.dark),
      ),
    );
  }
}

class ShowcaseCatalogScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const ShowcaseCatalogScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<ShowcaseCatalogScreen> createState() => _ShowcaseCatalogScreenState();
}

class _ShowcaseCatalogScreenState extends State<ShowcaseCatalogScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Reactivity',
    'Effects',
    'Scopes & DI',
    'ZenQuery',
    'Offline',
    'Case Studies',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Premium Header App Bar
          SliverAppBar.large(
            expandedHeight: 220,
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
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      bottom: -30,
                      child: Icon(
                        Icons.bolt,
                        size: 200,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'v2.2.1 • Production Ready',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    widget.isDark
                                        ? Icons.light_mode
                                        : Icons.dark_mode,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Toggle theme',
                                  onPressed: widget.onToggleTheme,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Interactive Demos & Architecture Catalog',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filter Chips
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: _categories.map((category) {
                  final isSelected = _selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(category),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedCategory = category);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Demo Cards Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _buildDemoSections(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDemoSections(BuildContext context) {
    final List<Widget> list = [];

    // Category 1: Reactivity & Basics
    if (_selectedCategory == 'All' || _selectedCategory == 'Reactivity') {
      list.add(const _CategoryHeader(
        title: 'Core Reactivity & Basics',
        subtitle:
            'Observable values, granular Obx, workers, and ZenView pattern',
        icon: Icons.refresh,
      ));

      list.add(_DemoCard(
        title: '1. Three-Step Counter',
        subtitle:
            'Minimal ZenModule + ZenController + ZenView pattern with ZenObserver & ZenUpdater.',
        tag: 'Beginner',
        tagColor: Colors.blue,
        icon: Icons.numbers,
        onTap: () => _openScreen(
          context,
          ZenProvider(
            moduleBuilder: () => CounterModule(),
            child: const CounterPage(),
          ),
        ),
      ));

      list.add(_DemoCard(
        title: '2. Observable State & Types',
        subtitle:
            'Live demo of RxInt, RxString, RxList, RxMap with automatic reactive tracking.',
        tag: 'Core',
        tagColor: Colors.teal,
        icon: Icons.tune,
        onTap: () => _openScreen(
          context,
          ZenProvider.create(
            create: () => ReactiveDemoController(),
            child: const ReactiveDemoPage(),
          ),
        ),
      ));

      list.add(_DemoCard(
        title: '3. Granular Obx Rebuilds',
        subtitle:
            'Targeted UI rebuilds only where observable state is consumed, without rebuilding parents.',
        tag: 'Performance',
        tagColor: Colors.orange,
        icon: Icons.visibility,
        onTap: () => _openScreen(
          context,
          ZenProvider.create(
            create: () => ReactiveDemoController(),
            child: const ObxDemoPage(),
          ),
        ),
      ));

      list.add(_DemoCard(
        title: '4. Reactive Workers',
        subtitle:
            'ever, once, debounce, interval side-effect workers with automatic disposal.',
        tag: 'Workers',
        tagColor: Colors.purple,
        icon: Icons.work,
        onTap: () => _openScreen(
          context,
          ZenProvider.create(
            create: () => WorkerDemoController(),
            child: const WorkerDemoPage(),
          ),
        ),
      ));

      list.add(_DemoCard(
        title: '5. ZenUpdater & Manual State',
        subtitle:
            'Fine-grained performance control with explicit update() notifications.',
        tag: 'Advanced',
        tagColor: Colors.indigo,
        icon: Icons.build,
        onTap: () => _openScreen(
          context,
          ZenProvider.create(
            create: () => ZenUpdaterDemoController(),
            child: const ZenUpdaterDemoPage(),
          ),
        ),
      ));

      list.add(const SizedBox(height: 24));
    }

    // Category 2: Effects
    if (_selectedCategory == 'All' || _selectedCategory == 'Effects') {
      list.add(const _CategoryHeader(
        title: 'Async Side Effects',
        subtitle: 'Managing complex asynchronous lifecycles with ZenEffects',
        icon: Icons.bolt,
      ));

      list.add(_DemoCard(
        title: 'ZenEffects & Async Builders',
        subtitle:
            'Structured states (idle, running, success, error) with ZenEffectBuilder and auto cancellation.',
        tag: 'Async',
        tagColor: Colors.deepPurple,
        icon: Icons.bolt,
        onTap: () => _openScreen(
          context,
          ZenProvider.create(
            create: () => EffectDemoController(),
            child: const EffectDemoPage(),
          ),
        ),
      ));

      list.add(const SizedBox(height: 24));
    }

    // Category 3: Scopes & DI
    if (_selectedCategory == 'All' || _selectedCategory == 'Scopes & DI') {
      list.add(const _CategoryHeader(
        title: 'Hierarchical Scopes & DI',
        subtitle:
            'Clean zero-config dependency injection with navigation hierarchies',
        icon: Icons.account_tree,
      ));

      list.add(_DemoCard(
        title: 'Canonical Nested Scopes (GoRouter ShellRoute)',
        subtitle:
            'Zero-config nested DI where child routes automatically inherit ancestor scopes.',
        tag: 'Recommended',
        tagColor: Colors.green,
        icon: Icons.route,
        onTap: () => _openScreen(
          context,
          const NestedScopesApp(),
        ),
      ));

      list.add(_DemoCard(
        title: 'Flat Scopes (Standard Navigator)',
        subtitle:
            'Explicit parent scope propagation for apps using traditional Navigator 1.0 push.',
        tag: 'Navigator 1.0',
        tagColor: Colors.blueGrey,
        icon: Icons.alt_route,
        onTap: () => _openScreen(
          context,
          const FlatScopesApp(),
        ),
      ));

      list.add(const SizedBox(height: 24));
    }

    // Category 4: ZenQuery
    if (_selectedCategory == 'All' || _selectedCategory == 'ZenQuery') {
      list.add(const _CategoryHeader(
        title: 'ZenQuery Suite',
        subtitle:
            'Asynchronous data fetching, caching, invalidation, and mutations',
        icon: Icons.query_stats,
      ));

      list.add(_DemoCard(
        title: 'Complete ZenQuery Demo Suite',
        subtitle:
            'Query caching, automated invalidation, mutation queue, infinite scrolling, and stream queries.',
        tag: 'Full Suite',
        tagColor: Colors.blue,
        icon: Icons.cloud_sync,
        onTap: () => _openScreen(
          context,
          const ZenQueryHomePage(),
        ),
      ));

      list.add(const SizedBox(height: 24));
    }

    // Category 5: Offline
    if (_selectedCategory == 'All' || _selectedCategory == 'Offline') {
      list.add(const _CategoryHeader(
        title: 'Offline-First Architecture',
        subtitle:
            'Persistent storage, mutation queuing, and automatic reconnection sync',
        icon: Icons.cloud_off,
      ));

      list.add(_DemoCard(
        title: 'Offline Feed & Mutation Queue',
        subtitle:
            'Production SharedPreferences ZenStorage, optimistic UI updates, and simulated network toggle.',
        tag: 'Offline First',
        tagColor: Colors.teal,
        icon: Icons.wifi_off,
        onTap: () {
          final simulator = NetworkSimulator();
          Zen.setNetworkStream(simulator.stream);
          _openScreen(
            context,
            ZenProvider.create(
              create: () => FeedController(),
              child: FeedPage(networkSimulator: simulator),
            ),
          );
        },
      ));

      list.add(const SizedBox(height: 24));
    }

    // Category 6: Case Studies
    if (_selectedCategory == 'All' || _selectedCategory == 'Case Studies') {
      list.add(const _CategoryHeader(
        title: 'Real-World Case Study Apps',
        subtitle: 'Complete production-pattern application architectures',
        icon: Icons.apps,
      ));

      list.add(_DemoCard(
        title: 'Todo App (CRUD & Storage)',
        subtitle:
            'Full Todo CRUD application with SharedPreferences persistence, filter bars, and effects.',
        tag: 'Case Study',
        tagColor: Colors.amber.shade800,
        icon: Icons.checklist,
        onTap: () => _openScreen(
          context,
          ZenProvider.create(
            create: () => TodoController(),
            child: const TodoHomePage(),
          ),
        ),
      ));

      list.add(_DemoCard(
        title: 'E-Commerce Store (Multi-Module)',
        subtitle:
            'Full enterprise multi-module architecture with Authentication, Catalog, Cart, and Checkout.',
        tag: 'Enterprise App',
        tagColor: Colors.deepOrange,
        icon: Icons.shopping_cart,
        onTap: () => _openScreen(
          context,
          const ECommerceApp(),
        ),
      ));
    }

    return list;
  }

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _CategoryHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final IconData icon;
  final VoidCallback onTap;

  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tagColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
