import 'package:zenify/zenify.dart';

import '../../../app/services/api_service.dart';
import '../../../app/services/cache_service.dart';
import '../../../app/services/navigation_service.dart';
import '../../../features/departments/services/employee_service.dart';
import '../controllers/employee_profile_controller.dart';
import '../services/employee_profile_service.dart';

/// Module for the employee profile feature
/// Demonstrates a feature module that registers feature-specific services
/// and inherits services from the parent scope
class EmployeeProfileModule extends ZenModule {
  final String employeeId;
  final String departmentId;

  EmployeeProfileModule({
    required this.employeeId,
    required this.departmentId,
  });

  @override
  String get name => 'EmployeeProfileModule';

  @override
  void register(ZenScope scope) {
    ZenLogger.logInfo('🚀 Registering Employee Profile-level services');

    // Get all services from scope hierarchy
    final apiService = scope.find<ApiService>();
    final cacheService = scope.find<CacheService>();
    final navigationService = scope.find<NavigationService>();
    final employeeService = scope.find<EmployeeService>();

    // Validate required dependencies
    if (apiService == null) {
      throw Exception('ApiService not found in scope hierarchy');
    }
    if (cacheService == null) {
      throw Exception('CacheService not found in scope hierarchy');
    }
    if (navigationService == null) {
      throw Exception('NavigationService not found in scope hierarchy');
    }
    if (employeeService == null) {
      throw Exception('EmployeeService not found in scope hierarchy');
    }

    // Register feature-specific services
    final employeeProfileService = EmployeeProfileService(
      apiService: apiService,
      cacheService: cacheService,
      employeeService: employeeService,
    );
    scope.put<EmployeeProfileService>(employeeProfileService,
        isPermanent: true);

    // Register the controller with ALL required dependencies
    scope.put<EmployeeProfileController>(
      EmployeeProfileController(
        employeeId: employeeId,
        departmentId: departmentId,
        cacheService: cacheService,
        navigationService: navigationService,
        employeeService: employeeService,
        employeeProfileService: employeeProfileService,
      ),
    );

    ZenLogger.logInfo('✅ Employee Profile-level services registered');
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    ZenLogger.logInfo('🔧 Initializing Employee Profile Module...');
    ZenLogger.logInfo('✅ Employee Profile Module initialized successfully');
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    ZenLogger.logInfo('🧹 Disposing Employee Profile Module...');

    final employeeProfileService = scope.find<EmployeeProfileService>();
    employeeProfileService?.dispose();

    ZenLogger.logInfo('✅ Employee Profile Module disposed');
  }
}
