import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../shared/models/employee.dart';

/// Service for managing employees
/// Demonstrates a service that is registered in a feature module
/// and is available to child scopes
class EmployeeService {
  final ApiService _apiService;
  final CacheService _cacheService;

  // Reactive state
  final _employees = RxMap<String, List<Employee>>({});
  final _isLoading = false.obs();
  final _selectedEmployeeId = Rx<String?>(null);

  // Reactive getters
  RxMap<String, List<Employee>> get employees => _employees;
  RxBool get isLoading => _isLoading;
  Rx<String?> get selectedEmployeeId => _selectedEmployeeId;

  // Computed values
  Employee? get selectedEmployee {
    if (_selectedEmployeeId.value == null) return null;
    
    for (final employeeList in _employees.values) {
      final employee = employeeList.firstWhere(
        (emp) => emp.id == _selectedEmployeeId.value,
        orElse: () => throw Exception('Employee not found'),
      );
      if (employee.id == _selectedEmployeeId.value) {
        return employee;
      }
    }
    
    return null;
  }

  EmployeeService({
    required ApiService apiService,
    required CacheService cacheService,
  })  : _apiService = apiService,
        _cacheService = cacheService {
    ZenLogger.logInfo('EmployeeService created');
  }

  /// Load employees for a department
  Future<List<Employee>> loadEmployees(String departmentId) async {
    try {
      _isLoading.value = true;

      // Check cache first
      final cacheKey = 'employees_$departmentId';
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        final employees = _parseEmployeesResponse(cachedData);
        _employees[departmentId] = employees;
        ZenLogger.logInfo('Loaded ${employees.length} employees for department $departmentId from cache');
        return employees;
      }

      // Fetch from API
      final response = await _apiService.get('employees', params: {'departmentId': departmentId});
      final employees = _parseEmployeesResponse(response);
      
      // Update state
      _employees[departmentId] = employees;
      
      // Cache the result
      _cacheService.set(cacheKey, response, ttl: const Duration(minutes: 5));
      
      ZenLogger.logInfo('Loaded ${employees.length} employees for department $departmentId from API');
      return employees;
    } catch (e) {
      ZenLogger.logError('Failed to load employees for department $departmentId', e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Get employee by ID
  Future<Employee> getEmployee(String id) async {
    try {
      _isLoading.value = true;

      // Check cache first
      final cacheKey = 'employee_$id';
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        final employee = Employee.fromJson(cachedData['data']);
        ZenLogger.logInfo('Loaded employee $id from cache');
        return employee;
      }

      // Fetch from API
      final response = await _apiService.get('employee/$id');
      final employee = Employee.fromJson(response['data']);
      
      // Cache the result
      _cacheService.set(cacheKey, response, ttl: const Duration(minutes: 5));
      
      ZenLogger.logInfo('Loaded employee $id from API');
      return employee;
    } catch (e) {
      ZenLogger.logError('Failed to load employee $id', e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Select an employee
  void selectEmployee(String? id) {
    _selectedEmployeeId.value = id;
    ZenLogger.logInfo('Selected employee: $id');
  }

  /// Parse employees response
  List<Employee> _parseEmployeesResponse(Map<String, dynamic> response) {
    final List<dynamic> data = response['data'] as List<dynamic>;
    return data.map((item) => Employee.fromJson(item as Map<String, dynamic>)).toList();
  }

  void dispose() {
    ZenLogger.logInfo('EmployeeService disposed');
  }
}