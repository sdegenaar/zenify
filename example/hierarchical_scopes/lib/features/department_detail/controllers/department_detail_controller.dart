import 'package:zenify/zenify.dart';

import '../../../app/services/cache_service.dart';
import '../../../app/services/navigation_service.dart';
import '../../../features/departments/services/department_service.dart';
import '../../../features/departments/services/employee_service.dart';
import '../../../shared/models/team.dart';
import '../services/team_service.dart';
import '../../../shared/models/department.dart';
import '../../../shared/models/employee.dart';

/// Controller for the department detail page with ZenEffects
class DepartmentDetailController extends ZenController {
  final String departmentId;

  // Services injected via constructor
  final CacheService _cacheService;
  final NavigationService _navigationService;
  final DepartmentService _departmentService;
  final EmployeeService _employeeService;
  final TeamService _teamService;

  // UI State
  late final RxBool _isLoading;
  late final Rx<Department?> _department;
  late final RxList<Employee> _employees;
  late final RxList<Team> _teams;
  late final RxString _lastError;

  // ZenEffects for tracking operations - using createEffect pattern like departments controller
  late final loadDepartmentEffect =
      createEffect<Department>(name: 'loadDepartment');
  late final loadEmployeesEffect =
      createEffect<List<Employee>>(name: 'loadEmployees');
  late final loadTeamsEffect = createEffect<List<Team>>(name: 'loadTeams');
  late final refreshEffect = createEffect<bool>(name: 'refresh');
  late final navigationEffect = createEffect<void>(name: 'navigation');

  // Public getters for reactive state
  RxBool get isLoading => _isLoading;
  Rx<Department?> get department => _department;
  RxList<Employee> get employees => _employees;
  RxList<Team> get teams => _teams;
  RxString get lastError => _lastError;

  // Constructor with ALL dependencies injected
  DepartmentDetailController({
    required this.departmentId,
    required CacheService cacheService,
    required NavigationService navigationService,
    required DepartmentService departmentService,
    required EmployeeService employeeService,
    required TeamService teamService,
  })  : _cacheService = cacheService,
        _navigationService = navigationService,
        _departmentService = departmentService,
        _employeeService = employeeService,
        _teamService = teamService;

  @override
  void onInit() {
    super.onInit();

    // Initialize reactive state
    _isLoading = obs(true);
    _department = obs<Department?>(null);
    _employees = obs<List<Employee>>([]);
    _teams = obs<List<Team>>([]);
    _lastError = obs('');

    // Initialize effect watchers
    _initializeEffectWatchers();

    // Load department details
    _loadDepartmentDetails();

    ZenLogger.logInfo(
        '🏢 DepartmentDetailController initialized with ZenEffects');
  }

  /// Initialize effect watchers to respond to effect state changes
  void _initializeEffectWatchers() {
    // Watch load department effect
    loadDepartmentEffect.watch(
      this,
      onData: (department) {
        if (department != null) {
          _department.value = department;
          ZenLogger.logInfo(
              '🏢 Load department effect completed: ${department.name}');
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Failed to load department: $error';
          ZenLogger.logError('Load department failed', error);
        }
      },
    );

    // Watch load employees effect
    loadEmployeesEffect.watch(
      this,
      onData: (employees) {
        if (employees != null) {
          _employees.value = employees;
          ZenLogger.logInfo(
              '👥 Load employees effect completed: ${employees.length} employees');
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Failed to load employees: $error';
          ZenLogger.logError('Load employees failed', error);
        }
      },
    );

    // Watch load teams effect
    loadTeamsEffect.watch(
      this,
      onData: (teams) {
        if (teams != null) {
          _teams.value = teams;
          ZenLogger.logInfo(
              '🔥 Load teams effect completed: ${teams.length} teams');
        }
      },
      onError: (error) {
        if (error != null) {
          _lastError.value = 'Failed to load teams: $error';
          ZenLogger.logError('Load teams failed', error);
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

  Future<void> _loadDepartmentDetails() async {
    if (_isLoading.value) {
      try {
        _lastError.value = '';

        // Load department with effect tracking
        await loadDepartmentEffect.run(() async {
          final department =
              await _departmentService.getDepartment(departmentId);
          return department;
        });

        // Load employees with effect tracking
        await loadEmployeesEffect.run(() async {
          final employees = await _employeeService.loadEmployees(departmentId);
          return employees;
        });

        // Load teams with effect tracking
        await loadTeamsEffect.run(() async {
          final teams = await _teamService.loadTeams(departmentId);
          return teams;
        });
      } catch (e) {
        _lastError.value = 'Error loading department details: $e';
        ZenLogger.logError('Error loading department details', e);
      } finally {
        _isLoading.value = false;
      }
    }
  }

  /// Refresh department details with effect tracking
  Future<void> refreshDepartmentDetails() async {
    try {
      await refreshEffect.run(() async {
        _lastError.value = '';

        // Clear relevant cache entries
        _cacheService.remove('department_$departmentId');
        _cacheService.remove('employees_$departmentId');
        _cacheService.remove('teams_$departmentId');

        // Reload department details
        _isLoading.value = true;
        await _loadDepartmentDetails();

        return true;
      });
    } catch (e) {
      _lastError.value = 'Error refreshing department details: $e';
      ZenLogger.logError('Error refreshing department details', e);
    }
  }

  /// Navigate to employee profile with effect tracking
  void navigateToEmployeeProfile(String employeeId) {
    navigationEffect.run(() async {
      _employeeService.selectEmployee(employeeId);
      _navigationService.navigateTo('/employee/profile', arguments: {
        'employeeId': employeeId,
        'departmentId': departmentId,
      });
    });
  }

  /// Navigate to team detail with effect tracking
  void navigateToTeamDetail(String teamId) {
    navigationEffect.run(() async {
      _teamService.selectTeam(teamId);
      _navigationService
          .navigateTo('/team/$teamId', arguments: {'teamId': teamId});
    });
  }

  /// Clear error message
  void clearError() {
    _lastError.value = '';
  }

  /// Get specific employee by ID
  Employee? getEmployeeById(String employeeId) {
    try {
      return _employees.firstWhere((emp) => emp.id == employeeId);
    } catch (e) {
      return null;
    }
  }

  /// Get specific team by ID
  Team? getTeamById(String teamId) {
    return _teamService.getTeam(teamId, departmentId);
  }

  /// Get employees count for this department
  int get employeesCount => _employees.length;

  /// Get teams count for this department
  int get teamsCount => _teams.length;

  /// Check if department data is loaded
  bool get isDepartmentLoaded => _department.value != null;

  /// Get department name safely
  String get departmentName => _department.value?.name ?? 'Loading...';

  /// Get department description safely
  String get departmentDescription => _department.value?.description ?? '';

  @override
  void onClose() {
    ZenLogger.logInfo('🧹 DepartmentDetailController disposed');
    super.onClose();
  }
}
