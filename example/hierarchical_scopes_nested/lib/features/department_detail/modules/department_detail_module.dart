import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../app/services/navigation_service.dart';
import '../../../features/departments/services/department_service.dart';
import '../../../features/departments/services/employee_service.dart';
import '../controllers/department_detail_controller.dart';
import '../services/team_service.dart';

/// Module for the department detail feature
class DepartmentDetailModule extends ZenModule {
  final String departmentId;

  DepartmentDetailModule({required this.departmentId});

  @override
  String get name => 'DepartmentDetailModule';

  @override
  void register(ZenScope scope) {
    ZenLogger.logInfo('🚀 Registering Department Detail-level services');

    // Get all services from scope hierarchy
    final apiService = scope.find<ApiService>();
    final cacheService = scope.find<CacheService>();
    final departmentService = scope.find<DepartmentService>();
    final employeeService = scope.find<EmployeeService>();
    final navigationService = scope.find<NavigationService>();

    // Validate required dependencies
    if (apiService == null) {
      throw Exception('ApiService not found in scope hierarchy');
    }
    if (cacheService == null) {
      throw Exception('CacheService not found in scope hierarchy');
    }
    if (departmentService == null) {
      throw Exception('DepartmentService not found in scope hierarchy');
    }
    if (employeeService == null) {
      throw Exception('EmployeeService not found in scope hierarchy');
    }
    if (navigationService == null) {
      throw Exception('NavigationService not found in scope hierarchy');
    }

    // Register feature-specific services
    final teamService = TeamService(
      apiService: apiService,
      cacheService: cacheService,
      departmentService: departmentService,
    );
    scope.put<TeamService>(teamService, isPermanent: true);

    // Register the controller with ALL required dependencies
    scope.put<DepartmentDetailController>(
      DepartmentDetailController(
        departmentId: departmentId,
        cacheService: cacheService,
        navigationService: navigationService,
        departmentService: departmentService,
        employeeService: employeeService,
        teamService: teamService,
      ),
    );

    ZenLogger.logInfo('✅ Department Detail-level services registered');
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    ZenLogger.logInfo('🔧 Initializing Department Detail Module...');
    ZenLogger.logInfo('✅ Department Detail Module initialized successfully');
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    ZenLogger.logInfo('🧹 Disposing Department Detail Module...');

    final teamService = scope.find<TeamService>();
    teamService?.dispose();

    ZenLogger.logInfo('✅ Department Detail Module disposed');
  }
}
