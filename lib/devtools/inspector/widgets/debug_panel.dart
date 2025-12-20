// lib/devtools/inspector/widgets/debug_panel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'scope_tree_view.dart';
import 'query_cache_view.dart';
import 'dependency_list_view.dart';
import 'stats_view.dart';

/// Main debug panel with tabbed interface
class ZenDebugPanel extends StatefulWidget {
  final VoidCallback onClose;

  const ZenDebugPanel({
    super.key,
    required this.onClose,
  });

  @override
  State<ZenDebugPanel> createState() => _ZenDebugPanelState();
}

class _ZenDebugPanelState extends State<ZenDebugPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _panelHeight = 400;
  static const _minHeight = 200.0;
  static const _maxHeight = 600.0;
  int _refreshKey = 0;

  // Auto-refresh state
  bool _autoRefreshEnabled = false;
  Timer? _autoRefreshTimer;
  static const _autoRefreshInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _refreshKey++;
    });
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefreshEnabled = !_autoRefreshEnabled;

      if (_autoRefreshEnabled) {
        // Start auto-refresh timer
        _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
          _refresh();
        });
      } else {
        // Stop auto-refresh timer
        _autoRefreshTimer?.cancel();
        _autoRefreshTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: _panelHeight,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle and header
            _buildHeader(context),

            // Tab bar
            _buildTabBar(),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ScopeTreeView(key: ValueKey('scope_$_refreshKey')),
                  QueryCacheView(key: ValueKey('query_$_refreshKey')),
                  DependencyListView(key: ValueKey('deps_$_refreshKey')),
                  StatsView(key: ValueKey('stats_$_refreshKey')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _panelHeight =
              (_panelHeight - details.delta.dy).clamp(_minHeight, _maxHeight);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Header row
            Row(
              children: [
                // Zen logo
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.purple[700],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      'Z',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zenify Inspector',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Development Tools',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                // Auto-refresh toggle
                IconButton(
                  onPressed: _toggleAutoRefresh,
                  icon: Icon(
                    _autoRefreshEnabled
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: _autoRefreshEnabled
                        ? Colors.green[400]
                        : Colors.grey[400],
                  ),
                ),
                // Manual refresh
                IconButton(
                  onPressed: _refresh,
                  icon: Icon(
                    Icons.refresh,
                    color: Colors.white.withValues(
                      alpha: _autoRefreshEnabled ? 0.5 : 1.0,
                    ),
                  ),
                ),
                // Close button
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.purple[400],
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[500],
        tabs: const [
          Tab(
            icon: Icon(Icons.account_tree, size: 20),
            text: 'Scopes',
          ),
          Tab(
            icon: Icon(Icons.cached, size: 20),
            text: 'Queries',
          ),
          Tab(
            icon: Icon(Icons.extension, size: 20),
            text: 'Dependencies',
          ),
          Tab(
            icon: Icon(Icons.analytics, size: 20),
            text: 'Stats',
          ),
        ],
      ),
    );
  }
}
