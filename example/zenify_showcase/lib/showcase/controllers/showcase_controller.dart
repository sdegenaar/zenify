import 'package:zenify/zenify.dart';

class ShowcaseController extends ZenController {
  // Current page tracking
  final RxInt currentPageIndex = 0.obs();

  // App state
  final RxString appTitle = 'Zenify Features Showcase'.obs();
  final RxBool isDarkMode = false.obs();
  final RxBool showPerformanceOverlay = false.obs();

  // Navigation state
  final RxBool isNavigationExpanded = false.obs();
  final RxString selectedFeature = ''.obs();

  // Demo statistics
  final RxInt totalDemosViewed = 0.obs();
  final RxInt interactionsCount = 0.obs();
  final RxMap<String, int> featureUsageStats = <String, int>{}.obs();

  // Available demo pages
  final List<DemoPageInfo> demoPages = [
    DemoPageInfo(
      title: 'Reactive State',
      subtitle: 'Observables, Computed & State Management',
      icon: 'reactive',
      route: '/reactive',
      color: 0xFF2196F3, // Blue
      description:
          'Learn about reactive programming with Obx, Observable values, and computed properties.',
    ),
    DemoPageInfo(
      title: 'Effects',
      subtitle: 'Async Operations & Side Effects',
      icon: 'effects',
      route: '/effects',
      color: 0xFF9C27B0, // Purple
      description:
          'Manage async operations, loading states, and error handling with ZenEffect.',
    ),
    DemoPageInfo(
      title: 'Workers',
      subtitle: 'Reactive Event Handling',
      icon: 'workers',
      route: '/workers',
      color: 0xFF009688, // Teal
      description:
          'Handle reactive events with ever, debounce, throttle, and condition workers.',
    ),
    DemoPageInfo(
      title: 'Obx Reactivity',
      subtitle: 'Granular UI Updates',
      icon: 'obx',
      route: '/obx',
      color: 0xFFFF9800, // Orange
      description:
          'Optimize performance with granular reactive UI updates using Obx.',
    ),
    DemoPageInfo(
      title: 'ZenBuilder',
      subtitle: 'Controller Integration',
      icon: 'builder',
      route: '/builder',
      color: 0xFF4CAF50, // Green
      description:
          'Integrate controllers seamlessly with automatic lifecycle management.',
    ),
    DemoPageInfo(
      title: 'Dependency Injection',
      subtitle: 'Service Management',
      icon: 'di',
      route: '/di',
      color: 0xFFF44336, // Red
      description:
          'Manage dependencies with scoped injection and service modules.',
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    _initializeFeatureStats();
    _loadUserPreferences();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ShowcaseController initialized');
    }
  }

  void _initializeFeatureStats() {
    for (var page in demoPages) {
      featureUsageStats[page.title] = 0;
    }
  }

  void _loadUserPreferences() {
    // In a real app, you might load from SharedPreferences
    // For now, we'll use default values
    isDarkMode.value = false;
    showPerformanceOverlay.value = false;
  }

  // Navigation methods
  void navigateToPage(int index) {
    if (index >= 0 && index < demoPages.length) {
      currentPageIndex.value = index;
      selectedFeature.value = demoPages[index].title;
      totalDemosViewed.value++;
      _trackFeatureUsage(demoPages[index].title);

      if (ZenConfig.enableDebugLogs) {
        ZenLogger.logDebug('Navigated to page: ${demoPages[index].title}');
      }
    }
  }

  void navigateToFeature(String featureName) {
    final index = demoPages.indexWhere((page) => page.title == featureName);
    if (index != -1) {
      navigateToPage(index);
    }
  }

  void nextPage() {
    final nextIndex = (currentPageIndex.value + 1) % demoPages.length;
    navigateToPage(nextIndex);
  }

  void previousPage() {
    final prevIndex = currentPageIndex.value == 0
        ? demoPages.length - 1
        : currentPageIndex.value - 1;
    navigateToPage(prevIndex);
  }

  // App settings
  void toggleDarkMode() {
    isDarkMode.value = !isDarkMode.value;
    _trackInteraction();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Dark mode toggled: ${isDarkMode.value}');
    }
  }

  void togglePerformanceOverlay() {
    showPerformanceOverlay.value = !showPerformanceOverlay.value;
    _trackInteraction();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug(
          'Performance overlay toggled: ${showPerformanceOverlay.value}');
    }
  }

  void toggleNavigationExpansion() {
    isNavigationExpanded.value = !isNavigationExpanded.value;
    _trackInteraction();
  }

  // Statistics tracking
  void _trackFeatureUsage(String featureName) {
    final currentCount = featureUsageStats[featureName] ?? 0;
    featureUsageStats[featureName] = currentCount + 1;
    _trackInteraction();
  }

  void _trackInteraction() {
    interactionsCount.value++;
  }

  // Utility methods
  DemoPageInfo get currentPage => demoPages[currentPageIndex.value];

  String get currentPageTitle => currentPage.title;
  String get currentPageSubtitle => currentPage.subtitle;

  bool get isFirstPage => currentPageIndex.value == 0;
  bool get isLastPage => currentPageIndex.value == demoPages.length - 1;

  // Statistics computed properties
  int get totalFeatures => demoPages.length;

  double get averageUsagePerFeature {
    if (featureUsageStats.isEmpty) return 0.0;
    final total = featureUsageStats.values.fold(0, (sum, count) => sum + count);
    return total / featureUsageStats.length;
  }

  String get mostUsedFeature {
    if (featureUsageStats.isEmpty) return 'None';
    final maxEntry =
        featureUsageStats.entries.reduce((a, b) => a.value > b.value ? a : b);
    return maxEntry.key;
  }

  // Demo actions for showcase
  Future<void> runShowcaseDemo() async {
    for (int i = 0; i < demoPages.length; i++) {
      navigateToPage(i);
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  void resetStatistics() {
    totalDemosViewed.value = 0;
    interactionsCount.value = 0;
    featureUsageStats.clear();
    _initializeFeatureStats();

    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('Statistics reset');
    }
  }

  // Search functionality
  List<DemoPageInfo> searchFeatures(String query) {
    if (query.isEmpty) return demoPages;

    return demoPages.where((page) {
      return page.title.toLowerCase().contains(query.toLowerCase()) ||
          page.subtitle.toLowerCase().contains(query.toLowerCase()) ||
          page.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Quick actions
  void openRandomFeature() {
    final randomIndex = DateTime.now().millisecond % demoPages.length;
    navigateToPage(randomIndex);
  }

  void showAppInfo() {
    _trackInteraction();
    // This would typically show an info dialog
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('App info requested');
    }
  }

  @override
  void onClose() {
    if (ZenConfig.enableDebugLogs) {
      ZenLogger.logDebug('ShowcaseController disposed');
    }
    super.onClose();
  }
}

/// Data class for demo page information
class DemoPageInfo {
  final String title;
  final String subtitle;
  final String icon;
  final String route;
  final int color;
  final String description;

  const DemoPageInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
    required this.description,
  });

  @override
  String toString() => 'DemoPageInfo($title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DemoPageInfo &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          route == other.route;

  @override
  int get hashCode => title.hashCode ^ route.hashCode;
}
