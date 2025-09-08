import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../app/services/navigation_service.dart';
import '../../../app/routes/app_routes.dart';

/// Home controller showcasing hierarchical scoping benefits through reactive state
class HomeController extends ZenController with ZenTickerProvider {
  // UI State
  late final Rx<int> _selectedTab;
  late final RxBool _showDebugPanel;
  late final RxBool _isRefreshing;

  // Tab Controller
  late final TabController tabController;

  // Services (inherited from parent scope via hierarchy)
  late final ApiService _apiService;
  late final CacheService _cacheService;
  late final NavigationService _navigationService;

  // Performance tracking
  late final Rx<Map<String, dynamic>> _performanceMetrics;
  late final Rx<Map<String, dynamic>> _hierarchyStats;

  // Public getters for reactive state
  Rx<int> get selectedTab => _selectedTab;
  RxBool get showDebugPanel => _showDebugPanel;
  RxBool get isRefreshing => _isRefreshing;
  Rx<Map<String, dynamic>> get performanceMetrics => _performanceMetrics;
  Rx<Map<String, dynamic>> get hierarchyStats => _hierarchyStats;

  // Service getters
  ApiService get apiService => _apiService;
  CacheService get cacheService => _cacheService;
  NavigationService get navigationService => _navigationService;

  @override
  void onInit() {
    super.onInit();

    // Initialize reactive state
    _selectedTab = obs(0);
    _showDebugPanel = obs(false);
    _isRefreshing = obs(false);
    _performanceMetrics = obs<Map<String, dynamic>>({});
    _hierarchyStats = obs<Map<String, dynamic>>({});

    // Initialize TabController
    tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: _selectedTab.value,
    );

    // Listen to tab changes
    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        _selectedTab.value = tabController.index;
      }
    });

    // Get services from hierarchical scope
    _initializeServicesFromHierarchy();

    // Start performance monitoring
    _startPerformanceMonitoring();

    ZenLogger.logInfo(
        '🏠 HomeController initialized with hierarchical services');
  }

  void _initializeServicesFromHierarchy() {
    // Services are automatically available via hierarchical scoping
    _apiService = Zen.find<ApiService>();
    _cacheService = Zen.find<CacheService>();
    _navigationService = Zen.find<NavigationService>();

    ZenLogger.logInfo(
        '✅ All services inherited from parent scope successfully');
  }

  void _startPerformanceMonitoring() {
    // Monitor performance metrics every second
    interval(
      obs(DateTime.now()),
      (value) => _updatePerformanceMetrics(),
      const Duration(seconds: 1),
    );

    // Monitor hierarchy stats every 5 seconds
    interval(
      obs(DateTime.now()),
      (value) => _updateHierarchyStats(),
      const Duration(seconds: 5),
    );
  }

  void _updatePerformanceMetrics() {
    if (isDisposed) return;

    final apiStats = _apiService.getStats();
    final cacheStats = _cacheService.getStats();
    final navStats = _navigationService.getStats();

    _performanceMetrics.value = {
      'api': apiStats,
      'cache': cacheStats,
      'navigation': navStats,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  void _updateHierarchyStats() {
    if (isDisposed) return;

    final currentScope = Zen.currentScope;

    // Calculate hierarchy depth
    int depth = 0;
    ZenScope? scope = currentScope;
    while (scope?.parent != null) {
      depth++;
      scope = scope!.parent;
    }

    // Get all services in the hierarchy
    final allServices = <String>[];
    scope = currentScope;
    while (scope != null) {
      // Use ZenScopeInspector.getAllInstances() instead of scope.getAllInstances()
      allServices.addAll(ZenScopeInspector.getAllInstances(scope)
          .keys
          .map((key) => key.toString()));
      scope = scope.parent;
    }

    _hierarchyStats.value = {
      'depth': depth,
      'services': allServices.toSet().toList(),
      'serviceCount': allServices.toSet().length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Change the selected tab
  void changeTab(int index) {
    _selectedTab.value = index;
    tabController.animateTo(index);
  }

  /// Toggle the debug panel
  void toggleDebugPanel() {
    _showDebugPanel.value = !_showDebugPanel.value;
  }

  /// Navigate to departments page
  void navigateToDepartments() {
    _navigationService.pushBreadcrumb('Departments', AppRoutes.departments);
    _navigationService.navigateTo(AppRoutes.departments);
  }

  /// Navigate to employees page
  void navigateToEmployees() {
    _navigationService.pushBreadcrumb('Employees', AppRoutes.employeeProfile);
    _navigationService.navigateTo(AppRoutes.employeeProfile);
  }

  /// Navigate to settings page
  // void navigateToSettings() {
  //   _navigationService.pushBreadcrumb('Settings', AppRoutes.settings);
  //   _navigationService.navigateTo(AppRoutes.settings);
  // }

  /// Navigate to a specific route
  void navigateTo(String route) {
    _navigationService.navigateTo(route);
  }

  /// Show analytics dialog
  void showAnalyticsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analytics'),
        content: const Text('Analytics feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Get effect states for UI
  // Map<String, dynamic> getEffectStates() {
  //   return {
  //     'departments': _apiService.departmentsEffect.state.value,
  //     'allEmployees': _apiService.allEmployeesEffect.state.value,
  //   };
  // }

  /// Get API stats for UI
  Map<String, dynamic> getApiStats() {
    return _apiService.getStats();
  }

  /// Refresh data
  Future<void> refreshData() async {
    if (_isRefreshing.value) return;

    try {
      _isRefreshing.value = true;

      // Clear cache
      _cacheService.clear();

      // Update metrics
      _updatePerformanceMetrics();
      _updateHierarchyStats();

      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      _isRefreshing.value = false;
    }
  }

  @override
  void onDispose() {
    tabController.dispose();
    ZenLogger.logInfo('🧹 HomeController disposed');
    super.onDispose();
  }
}
