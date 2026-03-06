import 'package:flutter/material.dart';
import 'package:zenify_devtools/src/screens/scope_inspector_screen.dart';
import 'package:zenify_devtools/src/screens/query_cache_screen.dart';
import 'package:zenify_devtools/src/screens/metrics_screen.dart';

class ZenifyDevToolsHome extends StatefulWidget {
  const ZenifyDevToolsHome({super.key});

  @override
  State<ZenifyDevToolsHome> createState() => _ZenifyDevToolsHomeState();
}

class _ZenifyDevToolsHomeState extends State<ZenifyDevToolsHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Zenify Inspector'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.account_tree), text: 'Scopes'),
            Tab(icon: Icon(Icons.storage), text: 'Query Cache'),
            Tab(icon: Icon(Icons.analytics), text: 'Metrics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ScopeInspectorScreen(),
          QueryCacheScreen(),
          MetricsScreen(),
        ],
      ),
    );
  }
}
