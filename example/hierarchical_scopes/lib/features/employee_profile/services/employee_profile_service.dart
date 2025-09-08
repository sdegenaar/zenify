import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../features/departments/services/employee_service.dart';
import '../../../shared/models/employee.dart';

/// Service for managing employee profiles
/// Demonstrates a service that is registered in a feature module
/// and depends on services from parent scopes
class EmployeeProfileService {
  final ApiService _apiService;
  final CacheService _cacheService;
  final EmployeeService _employeeService;

  // Reactive state
  final _employeeProfiles = RxMap<String, Employee>({});
  final _isLoading = false.obs();
  final _currentEmployeeId = Rx<String?>(null);
  final _employeeEffect = createEffect<Employee>(name: 'employeeEffect');

  // Reactive getters
  RxMap<String, Employee> get employeeProfiles => _employeeProfiles;
  RxBool get isLoading => _isLoading;
  Rx<String?> get currentEmployeeId => _currentEmployeeId;
  ZenEffect<Employee> get employeeEffect => _employeeEffect;

  // Computed values
  Employee? get currentEmployee => _currentEmployeeId.value == null
      ? null
      : _employeeProfiles[_currentEmployeeId.value];

  EmployeeProfileService({
    required ApiService apiService,
    required CacheService cacheService,
    required EmployeeService employeeService,
  })  : _apiService = apiService,
        _cacheService = cacheService,
        _employeeService = employeeService {
    ZenLogger.logInfo('EmployeeProfileService created');
  }

  /// Load employee profile
  Future<Employee> loadEmployeeProfile(String employeeId) async {
    try {
      _isLoading.value = true;
      _employeeEffect.loading();
      _currentEmployeeId.value = employeeId;

      // Check if we already have the employee
      if (_employeeProfiles.containsKey(employeeId)) {
        final employee = _employeeProfiles[employeeId]!;
        _employeeEffect.success(employee);
        ZenLogger.logInfo('Loaded employee profile $employeeId from cache');
        return employee;
      }

      // Check if the employee service has the employee
      if (_employeeService.selectedEmployeeId.value == employeeId) {
        final employee = _employeeService.selectedEmployee;
        if (employee != null) {
          _employeeProfiles[employeeId] = employee;
          _employeeEffect.success(employee);
          ZenLogger.logInfo(
              'Loaded employee profile $employeeId from employee service');
          return employee;
        }
      }

      // Check cache first
      final cacheKey = 'employee_$employeeId';
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        final employee = Employee.fromJson(cachedData['data']);
        _employeeProfiles[employeeId] = employee;
        _employeeEffect.success(employee);
        ZenLogger.logInfo('Loaded employee profile $employeeId from cache');
        return employee;
      }

      // Fetch from API
      final response = await _apiService.get('employee/$employeeId');
      final employee = Employee.fromJson(response['data']);

      // Update state
      _employeeProfiles[employeeId] = employee;

      // Cache the result
      _cacheService.set(cacheKey, response, ttl: const Duration(minutes: 5));

      // Update effect
      _employeeEffect.success(employee);

      ZenLogger.logInfo('Loaded employee profile $employeeId from API');
      return employee;
    } catch (e) {
      ZenLogger.logError('Failed to load employee profile $employeeId', e);
      _employeeEffect.setError(e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Get employee activities/history
  Future<List<Map<String, dynamic>>> getEmployeeActivities(
      String employeeId) async {
    try {
      // Check cache first
      final cacheKey = 'employee_activities_$employeeId';
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        return _parseActivitiesFromResponse(cachedData);
      }

      // Fetch from API
      final response = await _apiService.get('employee/$employeeId/activities');
      final activities = _parseActivitiesFromResponse(response);

      // Cache the result
      _cacheService.set(cacheKey, response, ttl: const Duration(minutes: 5));

      ZenLogger.logInfo(
          'Loaded ${activities.length} activities for employee $employeeId');
      return activities;
    } catch (e) {
      ZenLogger.logError(
          'Failed to load activities for employee $employeeId', e);
      // Return mock data as fallback
      return _getMockActivities();
    }
  }

  /// Parse activities from API response, handling different response formats
  List<Map<String, dynamic>> _parseActivitiesFromResponse(
      Map<String, dynamic> response) {
    final data = response['data'];

    // Handle case where data is a list
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }

    // Handle case where data is a map with activities array
    if (data is Map<String, dynamic>) {
      if (data.containsKey('activities') && data['activities'] is List) {
        return List<Map<String, dynamic>>.from(data['activities']);
      }

      // Handle case where data is a map with items array
      if (data.containsKey('items') && data['items'] is List) {
        return List<Map<String, dynamic>>.from(data['items']);
      }

      // Handle case where the entire data object represents a single activity
      // Convert it to a list with one item
      return [Map<String, dynamic>.from(data)];
    }

    // If we can't parse it, return empty list
    ZenLogger.logWarning(
        'Unexpected activities response format: ${data.runtimeType}');
    return [];
  }

  /// Get mock activities as fallback
  List<Map<String, dynamic>> _getMockActivities() {
    return [
      {
        'id': '1',
        'type': 'login',
        'description': 'Logged into system',
        'timestamp':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
      {
        'id': '2',
        'type': 'task_completed',
        'description': 'Completed quarterly report',
        'timestamp':
            DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      },
      {
        'id': '3',
        'type': 'meeting',
        'description': 'Attended team standup',
        'timestamp':
            DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      },
    ];
  }

  /// Get employee skills
  List<String> getEmployeeSkills(String employeeId) {
    final employee = _employeeProfiles[employeeId];
    return employee?.skills ?? [];
  }

  /// Get employee projects
  List<Project> getEmployeeProjects(String employeeId) {
    final employee = _employeeProfiles[employeeId];
    return employee?.projects ?? [];
  }

  void dispose() {
    _employeeEffect.dispose();
    ZenLogger.logInfo('EmployeeProfileService disposed');
  }
}
