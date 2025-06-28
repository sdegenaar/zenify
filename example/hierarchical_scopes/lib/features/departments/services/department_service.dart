import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../shared/models/department.dart';

/// Service for managing departments
/// Demonstrates a service that is registered in a feature module
/// and is available to child scopes
class DepartmentService {
  final ApiService _apiService;
  final CacheService _cacheService;

  // Reactive state
  final _departments = RxList<Department>([]);
  final _isLoading = false.obs();
  final _selectedDepartmentId = Rx<String?>(null);

  // Reactive getters
  RxList<Department> get departments => _departments;
  RxBool get isLoading => _isLoading;
  Rx<String?> get selectedDepartmentId => _selectedDepartmentId;

  // Computed values
  Department? get selectedDepartment => _selectedDepartmentId.value == null
      ? null
      : _departments.firstWhere(
        (dept) => dept.id == _selectedDepartmentId.value,
    orElse: () => throw Exception('Department not found'),
  );

  DepartmentService({
    required ApiService apiService,
    required CacheService cacheService,
  })  : _apiService = apiService,
        _cacheService = cacheService {
    ZenLogger.logInfo('DepartmentService created');
  }

  /// Get all departments (from cache or load if needed)
  Future<List<Department>> getDepartments() async {
    // If we already have departments and they're fresh, return them
    if (_departments.isNotEmpty) {
      return _departments.toList();
    }

    // Otherwise load them
    return await loadDepartments();
  }

  /// Load all departments (always fetches fresh data)
  Future<List<Department>> loadDepartments() async {
    try {
      _isLoading.value = true;

      // Check cache first
      final cachedData = _cacheService.get<Map<String, dynamic>>('departments');
      if (cachedData != null) {
        final departments = _parseDepartmentsResponse(cachedData);
        _departments.value = departments;
        ZenLogger.logInfo('Loaded ${departments.length} departments from cache');
        return departments;
      }

      // Fetch from API
      final response = await _apiService.get('departments');
      final departments = _parseDepartmentsResponse(response);

      // Update state
      _departments.value = departments;

      // Cache the result
      _cacheService.set('departments', response, ttl: const Duration(minutes: 5));

      ZenLogger.logInfo('Loaded ${departments.length} departments from API');
      return departments;
    } catch (e) {
      ZenLogger.logError('Failed to load departments', e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Force refresh departments from API
  Future<List<Department>> refreshDepartments() async {
    _cacheService.remove('departments'); // Clear cache first
    return await loadDepartments();
  }

  /// Get department by ID
  Future<Department> getDepartment(String id) async {
    try {
      _isLoading.value = true;

      // Check cache first
      final cacheKey = 'department_$id';
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        final department = Department.fromJson(cachedData['data']);
        ZenLogger.logInfo('Loaded department $id from cache');
        return department;
      }

      // Fetch from API
      final response = await _apiService.get('department/$id');
      final department = Department.fromJson(response['data']);

      // Cache the result
      _cacheService.set(cacheKey, response, ttl: const Duration(minutes: 5));

      ZenLogger.logInfo('Loaded department $id from API');
      return department;
    } catch (e) {
      ZenLogger.logError('Failed to load department $id', e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Select a department
  void selectDepartment(String? id) {
    _selectedDepartmentId.value = id;
    ZenLogger.logInfo('Selected department: $id');
  }

  /// Parse departments response
  List<Department> _parseDepartmentsResponse(Map<String, dynamic> response) {
    final List<dynamic> data = response['data'] as List<dynamic>;
    return data
        .map((item) {
      final itemMap = item as Map<String, dynamic>;
      return Department.fromJson({
        'id': itemMap['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'name': itemMap['name']?.toString() ?? 'Unknown Department',
        'description': itemMap['description']?.toString() ?? 'Department of ${itemMap['name'] ?? 'Unknown'}',
        'employeeCount': itemMap['employeeCount'] ?? 0,
        'budget': itemMap['budget']?.toDouble() ?? 0.0,
        'teams': itemMap['teams'] ?? [],
      });
    })
        .toList();
  }


  void dispose() {
    ZenLogger.logInfo('DepartmentService disposed');
  }
}