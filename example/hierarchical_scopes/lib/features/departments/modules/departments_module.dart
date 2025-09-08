import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../app/services/navigation_service.dart';
import '../controllers/departments_controller.dart';
import '../services/department_service.dart';
import '../services/employee_service.dart';

/// Module for the departments feature
/// Demonstrates a feature module that registers feature-specific services
/// and inherits services from the parent scope
class DepartmentsModule extends ZenModule {
  @override
  String get name => 'DepartmentsModule';

  @override
  void register(ZenScope scope) {
    ZenLogger.logInfo('🚀 Registering Departments-level services');

    final apiService = Zen.find<ApiService>();
    final cacheService = Zen.find<CacheService>();
    final navigationService = Zen.find<NavigationService>();

    // Register feature-specific services
    final departmentService = scope.put<DepartmentService>(
      DepartmentService(
        apiService: apiService,
        cacheService: cacheService,
      ),
    );

    scope.put<EmployeeService>(
      EmployeeService(
        apiService: apiService,
        cacheService: cacheService,
      ),
    );

    scope.put(DepartmentsController(
        departmentService: departmentService,
        navigationService: navigationService));

    ZenLogger.logInfo(
        '✅ Departments-level services registered: DepartmentService, EmployeeService');
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    ZenLogger.logInfo('🔧 Initializing Departments Module...');

    // Pre-load departments data
    final departmentService = scope.find<DepartmentService>()!;
    await departmentService.loadDepartments();

    ZenLogger.logInfo('✅ Departments Module initialized successfully');
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    ZenLogger.logInfo('🧹 Disposing Departments Module...');

    // Cleanup services
    final departmentService = scope.find<DepartmentService>();
    final employeeService = scope.find<EmployeeService>();

    departmentService?.dispose();
    employeeService?.dispose();

    ZenLogger.logInfo('✅ Departments Module disposed');
  }
}
