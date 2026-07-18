import 'package:zenify/zenify.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../services/navigation_service.dart';
import '../routes/app_routes.dart';

/// Main application module that provides core shared services
/// This demonstrates the root of the hierarchical scope chain
class AppModule extends ZenModule {
  @override
  String get name => 'AppModule';

  @override
  void register(ZenScope scope) {
    ZenLogger.logInfo('🚀 Registering App-level services (Root Scope)');

    // Core infrastructure services - available to ALL child scopes
    scope.put<ApiService>(ApiService(), isPermanent: true);
    scope.put<CacheService>(CacheService(), isPermanent: true);
    scope.put<NavigationService>(NavigationService(), isPermanent: true);

    ZenLogger.logInfo(
        '✅ App-level services registered: ApiService, CacheService, NavigationService');
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    ZenLogger.logInfo('🔧 Initializing App Module...');

    // Initialize API service
    final apiService = scope.find<ApiService>()!;
    await apiService.initialize();

    // Initialize navigation with home breadcrumb
    final navigationService = scope.find<NavigationService>()!;
    navigationService.pushBreadcrumb('Home', AppRoutes.home);

    // Pre-warm cache with common data
    final cacheService = scope.find<CacheService>()!;
    await _preWarmCache(cacheService, apiService);

    ZenLogger.logInfo('✅ App Module initialized successfully');
    ZenLogger.logInfo(
        '📊 Available services: ${ZenScopeInspector.getAllInstances(scope).keys.length}');
  }

  /// Pre-warm cache with commonly accessed data
  Future<void> _preWarmCache(CacheService cache, ApiService api) async {
    try {
      ZenLogger.logInfo('🔥 Pre-warming cache...');

      // Cache app metadata
      cache.set('app_version', '1.0.0', ttl: const Duration(hours: 1));
      cache.set('app_name', 'Company App 2', ttl: const Duration(hours: 1));

      // Pre-fetch departments data
      final departments = await api.get('departments');
      cache.set('departments', departments, ttl: const Duration(minutes: 5));

      ZenLogger.logInfo(
          '✅ Cache pre-warmed with app metadata and departments data');
    } catch (e) {
      ZenLogger.logError('Failed to pre-warm cache', e);
    }
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    ZenLogger.logInfo('🧹 Disposing App Module...');

    // Cleanup services
    final cacheService = scope.find<CacheService>();
    final navigationService = scope.find<NavigationService>();
    final apiService = scope.find<ApiService>();

    cacheService?.dispose();
    navigationService?.dispose();
    apiService?.dispose();

    ZenLogger.logInfo('✅ App Module disposed');
  }
}
