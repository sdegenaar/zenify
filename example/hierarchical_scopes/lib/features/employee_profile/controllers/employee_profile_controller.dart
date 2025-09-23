import 'package:zenify/zenify.dart';

import '../../../app/services/cache_service.dart';
import '../../../app/services/navigation_service.dart';
import '../../../features/departments/services/employee_service.dart';
import '../../../shared/models/employee.dart';
import '../services/employee_profile_service.dart';

/// Controller for the employee profile page with ZenEffects
class EmployeeProfileController extends ZenController {
  final String employeeId;
  final String departmentId;

  // Services injected via constructor
  final CacheService _cacheService;
  final NavigationService _navigationService;
  final EmployeeService _employeeService;
  final EmployeeProfileService _employeeProfileService;

  // UI State
  late final RxBool _isLoading;
  late final Rx<Employee?> _employee;
  late final RxList<Map<String, dynamic>> _activities;
  late final RxString _lastError;

  // ZenEffects for tracking operations - using createEffect pattern
  late final loadEmployeeEffect = createEffect<Employee>(name: 'loadEmployee');
  late final loadActivitiesEffect =
      createEffect<List<Map<String, dynamic>>>(name: 'loadActivities');
  late final refreshEffect = createEffect<bool>(name: 'refresh');
  late final navigationEffect = createEffect<void>(name: 'navigation');

  // Public getters for reactive state
  RxBool get isLoading => _isLoading;
  Rx<Employee?> get employee => _employee;
  RxList<Map<String, dynamic>> get activities => _activities;
  RxString get lastError => _lastError;

  // Constructor with ALL dependencies injected
  EmployeeProfileController({
    required this.employeeId,
    required this.departmentId,
    required CacheService cacheService,
    required NavigationService navigationService,
    required EmployeeService employeeService,
    required EmployeeProfileService employeeProfileService,
  })  : _cacheService = cacheService,
        _navigationService = navigationService,
        _employeeService = employeeService,
        _employeeProfileService = employeeProfileService;

  @override
  void onInit() {
    super.onInit();

    // Initialize reactive state
    _isLoading = obs(true);
    _employee = obs<Employee?>(null);
    _activities = obs<List<Map<String, dynamic>>>([]);
    _lastError = obs('');

    // Initialize effect watchers
    _initializeEffectWatchers();

    // Load employee profile
    _loadEmployeeProfile();

    ZenLogger.logInfo(
        '👤 EmployeeProfileController initialized with ZenEffects');
  }

  /// Initialize effect watchers to respond to effect state changes
  void _initializeEffectWatchers() {
    // Watch load employee effect
    loadEmployeeEffect.watch(
      this,
      onData: (employee) {
        if (employee != null) {
          _employee.value = employee;
          ZenLogger.logInfo(
              '👤 Load employee effect completed: ${employee.name}');
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Failed to load employee: $error';
          ZenLogger.logError('Load employee failed', error);
        }
      },
    );

    // Watch load activities effect
    loadActivitiesEffect.watch(
      this,
      onData: (activities) {
        if (activities != null) {
          _activities.value = activities;
          ZenLogger.logInfo(
              '📋 Load activities effect completed: ${activities.length} activities');
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Failed to load activities: $error';
          ZenLogger.logError('Load activities failed', error);
        }
      },
    );

    // Watch refresh effect
    refreshEffect.watch(
      this,
      onData: (success) {
        if (success == true) {
          _lastError.value = '';
          ZenLogger.logInfo('🔄 Refresh effect completed successfully');
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
          _isLoading.value = false;
        }
      },
    );

    // Watch navigation effect
    navigationEffect.watch(
      this,
      onData: (_) {
        ZenLogger.logInfo('🧭 Navigation effect completed');
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Navigation failed: $error';
          ZenLogger.logError('Navigation failed', error);
        }
      },
    );
  }

  Future<void> _loadEmployeeProfile() async {
    try {
      _lastError.value = '';
      ZenLogger.logInfo('Loading employee profile for $employeeId');

      // Load employee details with effect tracking
      await loadEmployeeEffect.run(() async {
        final employee = await _employeeService.getEmployee(employeeId);
        ZenLogger.logInfo('Employee loaded: ${employee.name}');
        return employee;
      });

      // Load employee activities with effect tracking
      await loadActivitiesEffect.run(() async {
        try {
          final activities =
              await _employeeProfileService.getEmployeeActivities(employeeId);
          ZenLogger.logInfo('Activities loaded: ${activities.length} items');
          return activities;
        } catch (e) {
          ZenLogger.logWarning('getEmployeeActivities failed: $e');
          // Provide mock activities as fallback
          return [
            {
              'id': '1',
              'type': 'login',
              'description': 'Logged into system',
              'timestamp': DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .toIso8601String(),
            },
            {
              'id': '2',
              'type': 'task_completed',
              'description': 'Completed quarterly report',
              'timestamp': DateTime.now()
                  .subtract(const Duration(hours: 5))
                  .toIso8601String(),
            },
            {
              'id': '3',
              'type': 'meeting',
              'description': 'Attended team standup',
              'timestamp': DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
            },
          ];
        }
      });
    } catch (e) {
      _lastError.value = 'Error loading employee profile: $e';
      ZenLogger.logError('Error loading employee profile: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  /// Refresh employee profile with effect tracking
  Future<void> refreshEmployeeProfile() async {
    try {
      await refreshEffect.run(() async {
        _lastError.value = '';

        // Clear relevant cache entries
        _cacheService.remove('employee_$employeeId');
        _cacheService.remove('employee_activities_$employeeId');

        // Reload employee profile
        _isLoading.value = true;
        await _loadEmployeeProfile();

        return true;
      });
    } catch (e) {
      _lastError.value = 'Error refreshing employee profile: $e';
      ZenLogger.logError('Error refreshing employee profile: $e');
    }
  }

  /// Navigate back to department detail with effect tracking
  void navigateBackToDepartment() {
    navigationEffect.run(() async {
      _navigationService.navigateTo('/department/detail', arguments: {
        'departmentId': departmentId,
      });
    });
  }

  /// Navigate back using the navigation service with effect tracking
  void goBack() {
    navigationEffect.run(() async {
      if (_navigationService.canGoBack()) {
        _navigationService.goBack();
      } else {
        // Fallback to department detail
        _navigationService.navigateTo('/department/detail', arguments: {
          'departmentId': departmentId,
        });
      }
    });
  }

  /// Clear error message
  void clearError() {
    _lastError.value = '';
  }

  /// Get employee name safely
  String get employeeName => _employee.value?.name ?? 'Loading...';

  /// Get employee email safely
  String get employeeEmail => _employee.value?.email ?? '';

  /// Get employee position safely
  String get employeePosition => _employee.value?.position ?? '';

  /// Get employee department ID safely
  String get employeeDepartmentId =>
      _employee.value?.departmentId ?? departmentId;

  /// Get employee phone safely
  String get employeePhone => _employee.value?.phone ?? '';

  /// Get employee hire date safely
  String get employeeHireDate => _employee.value?.hireDate ?? '';

  /// Get employee address safely
  String get employeeAddress => _employee.value?.address ?? '';

  /// Get employee skills safely
  List<String> get employeeSkills => _employee.value?.skills ?? [];

  /// Get employee projects safely
  List<Project> get employeeProjects => _employee.value?.projects ?? [];

  /// Check if employee data is loaded
  bool get isEmployeeLoaded => _employee.value != null;

  /// Get activities count
  int get activitiesCount => _activities.length;

  @override
  void onClose() {
    ZenLogger.logInfo('🧹 EmployeeProfileController disposed');
    super.onClose();
  }
}
