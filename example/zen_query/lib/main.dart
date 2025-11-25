import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import 'modules/zen_query_module.dart';
import 'pages/query_basics_page.dart';
import 'pages/mutation_page.dart';
import 'pages/infinite_query_page.dart';
import 'pages/stream_query_page.dart';
import 'pages/advanced_features_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Zenify
  Zen.init();

  // Configure for development with detailed logging
  ZenConfig.applyEnvironment(ZenEnvironment.development);

  ZenLogger.init(
    logHandler: (message, level) {
      if (kDebugMode) {
        developer.log(
          'ZEN [${level.toString().split('.').last.toUpperCase()}]: $message',
          name: 'ZenifyQuery',
        );
      }
    },
  );

  // Register modules
  await Zen.registerModules([
    ZenQueryModule(),
  ]);

  runApp(const ZenQueryApp());
}

class ZenQueryApp extends StatelessWidget {
  const ZenQueryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenQuery Complete Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// Home page with tab navigation
/// Uses StatefulWidget for UI state (TabController)
/// Business logic is handled by individual page controllers
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenQuery Complete Example'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Query Basics', icon: Icon(Icons.query_stats)),
            Tab(text: 'Mutations', icon: Icon(Icons.edit)),
            Tab(text: 'Infinite Query', icon: Icon(Icons.view_list)),
            Tab(text: 'Stream Query', icon: Icon(Icons.stream)),
            Tab(text: 'Advanced', icon: Icon(Icons.code)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          QueryBasicsPage(),
          MutationPage(),
          InfiniteQueryPage(),
          StreamQueryPage(),
          AdvancedFeaturesPage(),
        ],
      ),
    );
  }
}
