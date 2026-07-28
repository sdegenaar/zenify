import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../features/departments/services/department_service.dart';
import '../../../shared/models/department.dart';
import '../../../shared/models/team.dart';

/// Service for managing teams within a department
/// Demonstrates a service that is registered in a feature module
/// and depends on services from parent scopes
class TeamService {
  final ApiService _apiService;
  final CacheService _cacheService;
  final DepartmentService _departmentService;

  // Reactive state
  final _teams = RxMap<String, List<Team>>({});
  final _isLoading = false.obs();
  final _selectedTeamId = Rx<String?>(null);

  // Reactive getters
  RxMap<String, List<Team>> get teams => _teams;
  RxBool get isLoading => _isLoading;
  Rx<String?> get selectedTeamId => _selectedTeamId;

  // Computed values
  Team? get selectedTeam {
    if (_selectedTeamId.value == null) return null;

    for (final teamList in _teams.values) {
      for (final team in teamList) {
        if (team.id == _selectedTeamId.value) {
          return team;
        }
      }
    }

    return null;
  }

  TeamService({
    required ApiService apiService,
    required CacheService cacheService,
    required DepartmentService departmentService,
  })  : _apiService = apiService,
        _cacheService = cacheService,
        _departmentService = departmentService {
    ZenLogger.logInfo('TeamService created');
  }

  /// Load teams for a department
  Future<List<Team>> loadTeams(String departmentId) async {
    try {
      _isLoading.value = true;

      // Check if we already have the department with teams
      if (_departmentService.selectedDepartmentId.value == departmentId) {
        final department = _departmentService.selectedDepartment;
        if (department != null && department.teams.isNotEmpty) {
          _teams[departmentId] = department.teams;
          ZenLogger.logInfo(
              'Loaded ${department.teams.length} teams for department $departmentId from department service');
          return department.teams;
        }
      }

      // Check cache first
      final cacheKey = 'department_$departmentId';
      final cachedData = _cacheService.get<Map<String, dynamic>>(cacheKey);
      if (cachedData != null) {
        final department = Department.fromJson(cachedData['data']);
        _teams[departmentId] = department.teams;
        ZenLogger.logInfo(
            'Loaded ${department.teams.length} teams for department $departmentId from cache');
        return department.teams;
      }

      // Fetch from API
      final response = await _apiService.get('department/$departmentId');
      final department = Department.fromJson(response['data']);

      // Update state
      _teams[departmentId] = department.teams;

      // Cache the result
      _cacheService.set(cacheKey, response, ttl: const Duration(minutes: 5));

      ZenLogger.logInfo(
          'Loaded ${department.teams.length} teams for department $departmentId from API');
      return department.teams;
    } catch (e) {
      ZenLogger.logError(
          'Failed to load teams for department $departmentId', e);
      rethrow;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Select a team
  void selectTeam(String? id) {
    _selectedTeamId.value = id;
    ZenLogger.logInfo('Selected team: $id');
  }

  /// Get team by ID
  Team? getTeam(String id, String departmentId) {
    final departmentTeams = _teams[departmentId];
    if (departmentTeams == null) return null;

    for (final team in departmentTeams) {
      if (team.id == id) {
        return team;
      }
    }

    return null;
  }

  void dispose() {
    ZenLogger.logInfo('TeamService disposed');
  }
}
