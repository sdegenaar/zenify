import 'dart:async';
import 'dart:math';

import 'package:zenify/zenify.dart';

/// API service for making requests to the backend
/// Demonstrates a service that can be shared across hierarchical scopes
class ApiService {
  final _requestCount = 0.obs();
  final _lastRequestTime = Rx<DateTime?>(null);
  final _activeRequests = 0.obs();
  final _requestLog = RxList<ApiRequest>([]);
  final _random = Random();

  // Reactive getters
  Rx<int> get requestCount => _requestCount;
  Rx<DateTime?> get lastRequestTime => _lastRequestTime;
  Rx<int> get activeRequests => _activeRequests;
  RxList<ApiRequest> get requestLog => _requestLog;

  /// Initialize the API service
  Future<void> initialize() async {
    ZenLogger.logInfo('ApiService initialized');
    return Future.delayed(const Duration(milliseconds: 300));
  }

  /// Make a GET request to the API
  Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? params}) async {
    return _makeRequest('GET', endpoint, params: params);
  }

  /// Make a POST request to the API
  Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? data}) async {
    return _makeRequest('POST', endpoint, data: data);
  }

  /// Make a PUT request to the API
  Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? data}) async {
    return _makeRequest('PUT', endpoint, data: data);
  }

  /// Make a DELETE request to the API
  Future<Map<String, dynamic>> delete(String endpoint) async {
    return _makeRequest('DELETE', endpoint);
  }

  /// Make a request to the API with retry logic
  Future<Map<String, dynamic>> _makeRequest(
      String method,
      String endpoint, {
        Map<String, dynamic>? params,
        Map<String, dynamic>? data,
        int maxRetries = 3,
      }) async {
    final request = ApiRequest(
      id: 'req_${DateTime.now().millisecondsSinceEpoch}',
      method: method,
      endpoint: endpoint,
      params: params,
      data: data,
      timestamp: DateTime.now(),
    );

    // Update reactive state
    _requestCount.value++;
    _lastRequestTime.value = request.timestamp;
    _activeRequests.value++;
    _requestLog.add(request);

    // Trim request log if it gets too large
    if (_requestLog.length > 50) {
      _requestLog.value.removeRange(0, _requestLog.length - 50);  // Now works correctly
    }

    ZenLogger.logInfo('API Request: $method $endpoint');

    try {
      // Simulate network delay
      final delay = 300 + _random.nextInt(700);
      await Future.delayed(Duration(milliseconds: delay));

      // Simulate random failures (10% chance)
      if (_random.nextDouble() < 0.1 && maxRetries > 0) {
        throw Exception('Network error');
      }

      // Create mock response based on the endpoint
      final response = _createMockResponse(endpoint, method, params: params);

      // Update request with success
      request.status = 'success';
      request.responseTime = DateTime.now().difference(request.timestamp);
      _updateRequest(request);

      return response;
    } catch (e) {
      // Update request with error
      request.status = 'error';
      request.error = e.toString();
      request.responseTime = DateTime.now().difference(request.timestamp);
      _updateRequest(request);

      // Retry logic
      if (maxRetries > 0) {
        ZenLogger.logWarning('Retrying request: $method $endpoint (${maxRetries - 1} retries left)');
        return _makeRequest(method, endpoint, params: params, data: data, maxRetries: maxRetries - 1);
      }

      rethrow;
    } finally {
      _activeRequests.value--;
    }
  }

  /// Update a request in the request log
  void _updateRequest(ApiRequest request) {
    final index = _requestLog.value.indexWhere((r) => r.id == request.id);
    if (index >= 0) {
      _requestLog[index] = request;
    }
  }

  /// Create a mock response based on the endpoint
  Map<String, dynamic> _createMockResponse(String endpoint, String method, {Map<String, dynamic>? params}) {
    // Mock departments data with teams included
    if (endpoint.contains('departments')) {
      return {
        'data': [
          {
            'id': 'dept1', 
            'name': 'Engineering', 
            'employeeCount': 42, 
            'location': 'Building A',
            'teams': [
              {'id': 'team1', 'name': 'Backend Team', 'memberCount': 8},
              {'id': 'team2', 'name': 'Frontend Team', 'memberCount': 6},
              {'id': 'team3', 'name': 'DevOps Team', 'memberCount': 4},
            ]
          },
          {
            'id': 'dept2', 
            'name': 'Marketing', 
            'employeeCount': 18, 
            'location': 'Building B',
            'teams': [
              {'id': 'team4', 'name': 'Digital Marketing', 'memberCount': 7},
              {'id': 'team5', 'name': 'Content Team', 'memberCount': 5},
              {'id': 'team6', 'name': 'Brand Team', 'memberCount': 6},
            ]
          },
          {
            'id': 'dept3', 
            'name': 'Finance', 
            'employeeCount': 15, 
            'location': 'Building C',
            'teams': [
              {'id': 'team7', 'name': 'Accounting', 'memberCount': 8},
              {'id': 'team8', 'name': 'Treasury', 'memberCount': 7},
            ]
          },
          {
            'id': 'dept4', 
            'name': 'Human Resources', 
            'employeeCount': 8, 
            'location': 'Building B',
            'teams': [
              {'id': 'team9', 'name': 'Recruitment', 'memberCount': 4},
              {'id': 'team10', 'name': 'Employee Relations', 'memberCount': 4},
            ]
          },
          {
            'id': 'dept5', 
            'name': 'Operations', 
            'employeeCount': 23, 
            'location': 'Building D',
            'teams': [
              {'id': 'team11', 'name': 'Logistics', 'memberCount': 9},
              {'id': 'team12', 'name': 'Quality Assurance', 'memberCount': 7},
              {'id': 'team13', 'name': 'Facilities', 'memberCount': 7},
            ]
          },
        ],
        'meta': {'total': 5, 'page': 1, 'perPage': 10}
      };
    }

    if (endpoint.contains('department/') && endpoint.split('/').length > 1) {
      final deptId = endpoint.split('/').last;
      final deptName = deptId == 'dept1' ? 'Engineering' :
      deptId == 'dept2' ? 'Marketing' :
      deptId == 'dept3' ? 'Finance' :
      deptId == 'dept4' ? 'Human Resources' : 'Operations';

      return {
        'data': {
          'id': deptId,
          'name': deptName,
          'description': 'This is the $deptName department',
          'employeeCount': _random.nextInt(50) + 5,
          'location': 'Building ${_random.nextInt(5) + 1}',
          'budget': (_random.nextInt(900) + 100) * 1000,
          'manager': 'emp${_random.nextInt(100) + 1}',
          'teams': List.generate(
            _random.nextInt(5) + 1,
                (i) => {
              'id': 'team${i + 1}',
              'name': '$deptName Team ${i + 1}',
              'memberCount': _random.nextInt(10) + 2,
            },
          ),
        }
      };
    }

    // Mock employees data
    if (endpoint.contains('employees')) {
      final deptId = params?['departmentId'] as String? ?? '';
      final deptName = deptId == 'dept1' ? 'Engineering' :
      deptId == 'dept2' ? 'Marketing' :
      deptId == 'dept3' ? 'Finance' :
      deptId == 'dept4' ? 'Human Resources' : 'Operations';

      return {
        'data': List.generate(
          _random.nextInt(20) + 5,
              (i) => {
            'id': 'emp${i + 1}',
            'name': 'Employee ${i + 1}',
            'position': '$deptName Specialist',
            'departmentId': deptId,
            'email': 'employee${i + 1}@company.com',
            'hireDate': '2023-${_random.nextInt(12) + 1}-${_random.nextInt(28) + 1}',
          },
        ),
        'meta': {'total': _random.nextInt(50) + 5, 'page': 1, 'perPage': 20}
      };
    }

    // Mock employee detail data
    if (endpoint.contains('employee/') && endpoint.split('/').length > 1) {
      final empId = endpoint.split('/').last;

      return {
        'data': {
          'id': empId,
          'name': 'Employee ${empId.replaceAll('emp', '')}',
          'position': 'Senior Specialist',
          'departmentId': 'dept${_random.nextInt(5) + 1}',
          'email': 'employee${empId.replaceAll('emp', '')}@company.com',
          'phone': '+1 ${_random.nextInt(900) + 100} ${_random.nextInt(900) + 100} ${_random.nextInt(9000) + 1000}',
          'hireDate': '2023-${_random.nextInt(12) + 1}-${_random.nextInt(28) + 1}',
          'address': '${_random.nextInt(1000) + 100} Main St, City',
          'skills': List.generate(
            _random.nextInt(5) + 1,
                (i) => 'Skill ${i + 1}',
          ),
          'projects': List.generate(
            _random.nextInt(3) + 1,
                (i) => {
              'id': 'proj${i + 1}',
              'name': 'Project ${i + 1}',
              'role': 'Team Member',
            },
          ),
        }
      };
    }

    // Default response
    return {
      'data': {'message': 'Mock response for $endpoint'},
      'meta': {'timestamp': DateTime.now().toIso8601String()}
    };
  }

  /// Get API statistics
  Map<String, dynamic> getStats() {
    return {
      'totalRequests': _requestCount.value,
      'activeRequests': _activeRequests.value,
      'lastRequestTime': _lastRequestTime.value?.toIso8601String(),
      'recentRequests': _requestLog.take(5).map((r) => r.toJson()).toList(),
    };
  }

  void dispose() {
    _requestLog.clear();
    ZenLogger.logInfo('ApiService disposed');
  }
}

/// API request model
class ApiRequest {
  final String id;
  final String method;
  final String endpoint;
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  String status = 'pending';
  String? error;
  Duration? responseTime;

  ApiRequest({
    required this.id,
    required this.method,
    required this.endpoint,
    this.params,
    this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'endpoint': endpoint,
      'params': params,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'error': error,
      'responseTime': responseTime?.inMilliseconds,
    };
  }
}