import 'package:zenify/zenify.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/services/navigation_service.dart';
import '../services/department_service.dart';
import '../../../shared/models/department.dart';

/// Controller for the departments page
class DepartmentsController extends ZenController {
  final DepartmentService _departmentService;
  final NavigationService _navigationService;

  // UI State - Initialize reactive variables
  late final RxString _searchQuery = ''.obs();
  late final RxBool _isRefreshing = false.obs();
  late final RxString _lastError = ''.obs();

  // ZenEffects for side effects - using createEffect pattern
  late final searchEffect = createEffect<String>(name: 'search');
  late final refreshEffect = createEffect<bool>(name: 'refresh');
  late final navigationEffect = createEffect<String>(name: 'navigation');

  // Getters for UI state
  RxString get searchQuery => _searchQuery;
  RxBool get isRefreshing => _isRefreshing;
  RxString get lastError => _lastError;

  // Computed properties that delegate to the service
  RxList<Department> get departments => _departmentService.departments;
  RxBool get isLoading => _departmentService.isLoading;

  DepartmentsController({
    required DepartmentService departmentService,
    required NavigationService navigationService,
  })  : _departmentService = departmentService,
        _navigationService = navigationService {
    ZenLogger.logInfo('DepartmentsController created');
  }

  @override
  void onInit() {
    super.onInit();
    ZenLogger.logInfo('DepartmentsController initialized');
    _initializeEffectWatchers();
    _loadInitialData();
  }

  /// Initialize effect watchers to respond to effect state changes
  void _initializeEffectWatchers() {
    // Watch search effect
    searchEffect.watch(
      this,
      onData: (searchTerm) {
        if (searchTerm != null && searchTerm.length > 2) {
          ZenLogger.logInfo('🔍 Search effect completed: $searchTerm');
          // Trigger UI update for filtered results
          update();
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Search failed: $error';
        }
      },
    );

    // Watch refresh effect
    refreshEffect.watch(
      this,
      onData: (success) {
        if (success == true) {
          ZenLogger.logInfo('🔄 Refresh effect completed successfully');
          _lastError.value = '';
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Failed to refresh: $error';
          ZenLogger.logError('Refresh failed', error);
        }
      },
      onLoading: (loading) {
        if (!loading) {
          _isRefreshing.value = false;
        }
      },
    );

    // Watch navigation effect
    navigationEffect.watch(
      this,
      onData: (departmentId) {
        if (departmentId != null) {
          ZenLogger.logInfo('🧭 Navigation effect completed: $departmentId');
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Navigation failed: $error';
        }
      },
    );
  }

  /// Load initial department data
  void _loadInitialData() async {
    try {
      await _departmentService.getDepartments();
      _lastError.value = '';

      // Debug logging to see what we actually got
      final depts = departments.value;
      ZenLogger.logInfo('Loaded ${depts.length} departments:');
      for (final dept in depts) {
        ZenLogger.logInfo('  - ${dept.name}: ${dept.teams.length} teams');
        if (dept.teams.isNotEmpty) {
          for (final team in dept.teams) {
            ZenLogger.logInfo(
                '    * ${team.name} (${team.members.length} members)');
          }
        }
      }
    } catch (e) {
      _lastError.value = 'Failed to load departments: $e';
      ZenLogger.logError('Failed to load initial departments', e);
    }
  }

  /// Search departments by query (triggers search effect)
  void search(String query) {
    _searchQuery.value = query;

    // Run the search effect
    searchEffect.run(() async {
      await Future.delayed(const Duration(milliseconds: 300)); // Debounce
      ZenLogger.logInfo('🔍 Search effect triggered: $query');
      // The actual filtering is handled by the computed property
      return query;
    });
  }

  /// Clear the current search query
  void clearSearch() {
    _searchQuery.value = '';
    searchEffect.reset();
  }

  /// Refresh departments from the server (triggers refresh effect)
  Future<void> refreshDepartments() async {
    if (_isRefreshing.value) return;
    _isRefreshing.value = true;

    // Run the refresh effect
    await refreshEffect.run(() async {
      ZenLogger.logInfo('🔄 Refresh effect triggered');
      await _departmentService.refreshDepartments();
      return true;
    });
  }

  /// Navigate to department detail page (triggers navigation effect)
  void navigateToDepartmentDetail(String departmentId) {
    _departmentService.selectDepartment(departmentId);

    // Run the navigation effect
    navigationEffect.run(() async {
      ZenLogger.logInfo('🧭 Navigation effect triggered: $departmentId');
      _navigationService.navigateTo(AppRoutes.departmentDetail,
          arguments: {'departmentId': departmentId});
      return departmentId;
    });
  }

  /// Get filtered departments based on search query
  List<Department> get filteredDepartments {
    final allDepartments = departments.value;
    final query = _searchQuery.value.toLowerCase().trim();

    if (query.isEmpty) {
      return allDepartments;
    }

    return allDepartments.where((department) {
      return department.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void onDispose() {
    ZenLogger.logInfo('🧹 DepartmentsController disposed');
    // Effects will be automatically disposed by the base controller
    super.onDispose();
  }
}
