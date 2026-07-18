import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zenify/zenify.dart';

import '../../features/home/modules/home_module.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/departments/modules/departments_module.dart';
import '../../features/departments/pages/departments_page.dart';
import '../../features/department_detail/modules/department_detail_module.dart';
import '../../features/department_detail/pages/department_detail_page.dart';
import '../../features/employee_profile/modules/employee_profile_module.dart';
import '../../features/employee_profile/pages/employee_profile_page.dart';
import '../services/navigation_service.dart';

/// Routes demonstrating deep hierarchical scoping using go_router's ShellRoute
class AppRoutes {
  static const String home = '/';
  static const String departments = '/departments';
  
  // Navigation helper methods
  static String departmentDetail(String departmentId) => '/departments/detail/$departmentId';
  static String employeeProfile(String departmentId, String employeeId) => '/departments/detail/$departmentId/employee/$employeeId';

  /// GoRouter configuration with declarative hierarchical scopes
  static final GoRouter router = GoRouter(
    navigatorKey: NavigationService.navigatorKey,
    initialLocation: home,
    routes: [
      GoRoute(
        path: home,
        builder: (context, state) {
          return ZenRoute(
            moduleBuilder: () => HomeModule(),
            page: const HomePage(),
            scopeName: 'HomeScope',
          );
        },
      ),

      // 🔥 The Canonical Way: ShellRoute for hierarchical scoping
      // The ShellRoute provides the 'DepartmentsScope' which all its child routes will natively inherit!
      ShellRoute(
        builder: (context, state, child) {
          return ZenRoute(
            moduleBuilder: () => DepartmentsModule(),
            scopeName: 'DepartmentsScope',
            // The child is the nested Navigator containing the sub-routes.
            // Because it renders inside ZenRoute, everything in the child navigator can find DepartmentsScope natively!
            page: child, 
          );
        },
        routes: [
          GoRoute(
            path: departments,
            // We don't need ZenRoute here for DepartmentsScope, because the ShellRoute already provided it!
            builder: (context, state) => const DepartmentsPage(),
            routes: [
              GoRoute(
                path: 'detail/:id',
                builder: (context, state) {
                  final departmentId = state.pathParameters['id'] ?? '';
                  
                  return ZenRoute(
                    moduleBuilder: () => DepartmentDetailModule(departmentId: departmentId),
                    scopeName: 'DepartmentDetailScope',
                    page: DepartmentDetailPage(departmentId: departmentId),
                    // 🔥 Zero Config! No need to explicitly pass `parentScope` because 
                    // this route is built inside the ShellRoute's nested Navigator!
                  );
                },
                routes: [
                  GoRoute(
                    path: 'employee/:empId',
                    builder: (context, state) {
                      final employeeId = state.pathParameters['empId'] ?? '';
                      final departmentId = state.pathParameters['id'] ?? '';
                      
                      return ZenRoute(
                        moduleBuilder: () => EmployeeProfileModule(
                            employeeId: employeeId, departmentId: departmentId),
                        scopeName: 'EmployeeProfileScope',
                        page: EmployeeProfilePage(
                          employeeId: employeeId,
                          departmentId: departmentId,
                        ),
                        // 🔥 Deepest level - inheriting seamlessly!
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text(
          '404 - Page not found\n${state.error}',
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
