import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../features/home/modules/home_module.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/departments/modules/departments_module.dart';
import '../../features/departments/pages/departments_page.dart';
import '../../features/department_detail/modules/department_detail_module.dart';
import '../../features/department_detail/pages/department_detail_page.dart';
import '../../features/employee_profile/modules/employee_profile_module.dart';
import '../../features/employee_profile/pages/employee_profile_page.dart';

/// Routes demonstrating deep hierarchical scoping
class AppRoutes {
  static const String home = '/';
  static const String departments = '/departments';
  static const String departmentDetail = '/department/detail';
  static const String employeeProfile = '/employee/profile';

  /// Route generator with deep hierarchical scope inheritance
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) {
            return ZenRoute(
              moduleBuilder: () {
                return HomeModule();
              },
              page: const HomePage(),
              scopeName: 'HomeScope',
            );
          },
        );

      case departments:
        return MaterialPageRoute(
          builder: (_) => ZenRoute(
            moduleBuilder: () => DepartmentsModule(),
            page: const DepartmentsPage(),
            scopeName: 'DepartmentsScope',
            // 🔥 Automatically inherits parent scope via widget tree!
            // Inherits: ApiService, CacheService, NavigationService
            // Registers: DepartmentService, EmployeeService (shared business logic)
          ),
        );

      case departmentDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        final departmentId = args?['departmentId'] as String? ?? '';

        return MaterialPageRoute(
          builder: (_) => ZenRoute(
            moduleBuilder: () =>
                DepartmentDetailModule(departmentId: departmentId),
            page: DepartmentDetailPage(departmentId: departmentId),
            scopeName: 'DepartmentDetailScope',
            // 🔥 Automatically inherits from DepartmentsScope!
          ),
        );

      case employeeProfile:
        final args = settings.arguments as Map<String, dynamic>?;
        final employeeId = args?['employeeId'] as String? ?? '';
        final departmentId = args?['departmentId'] as String? ?? '';

        return MaterialPageRoute(
          builder: (_) => ZenRoute(
            moduleBuilder: () => EmployeeProfileModule(
                employeeId: employeeId, departmentId: departmentId),
            page: EmployeeProfilePage(
              employeeId: employeeId,
              departmentId: departmentId,
            ),
            scopeName: 'EmployeeProfileScope',
            // 🔥 Deepest level - automatically inherits ALL shared services!
            // Has access to: ApiService, CacheService, DepartmentService, EmployeeService
            // Plus any controllers from department detail scope
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(
              child: Text(
                '404 - Page not found',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        );
    }
  }
}
