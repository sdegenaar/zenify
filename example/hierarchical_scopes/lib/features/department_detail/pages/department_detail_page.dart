import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../../shared/models/team.dart';
import '../../../shared/widgets/debug_dialog.dart';
import '../controllers/department_detail_controller.dart';
import '../../../shared/models/department.dart';
import '../../../shared/models/employee.dart';

/// Department detail page using ZenView pattern with ZenEffects
class DepartmentDetailPage extends ZenView<DepartmentDetailController> {
  final String departmentId;

  const DepartmentDetailPage({
    required this.departmentId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: ZenBuilder<DepartmentDetailController>(
        builder: (context, controller) {
          return Obx(() {
            final department = controller.department.value;
            return Text(department?.name ?? 'Department Details');
          });
        },
      ),
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        ZenBuilder<DepartmentDetailController>(
          builder: (context, controller) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Refresh button with ZenEffectBuilder
                ZenEffectBuilder<bool>(
                  effect: controller.refreshEffect,
                  onInitial: () => IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: controller.refreshDepartmentDetails,
                    tooltip: 'Refresh Details',
                  ),
                  onLoading: () => IconButton(
                    icon: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    onPressed: null,
                    tooltip: 'Refreshing...',
                  ),
                  onSuccess: (success) => IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: controller.refreshDepartmentDetails,
                    tooltip: 'Refresh Details',
                  ),
                  onError: (error) => IconButton(
                    icon: Icon(Icons.refresh, color: Colors.red.shade300),
                    onPressed: controller.refreshDepartmentDetails,
                    tooltip: 'Refresh Failed - Retry',
                  ),
                ),
                // Debug button
                IconButton(
                  icon: const Icon(Icons.developer_mode),
                  onPressed: () => _showDebugDialog(context),
                  tooltip: 'Debug Info',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showDebugDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DebugDialog(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Error banner
        ZenBuilder<DepartmentDetailController>(
          builder: (context, controller) {
            final errorMessage = controller.lastError.value;

            return errorMessage.isNotEmpty
                ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade700, size: 18),
                    onPressed: controller.clearError,
                  ),
                ],
              ),
            )
                : const SizedBox.shrink();
          },
        ),

        // Main content
        Expanded(
          child: ZenBuilder<DepartmentDetailController>(
            builder: (context, controller) {
              return Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading department details...'),
                      ],
                    ),
                  );
                }

                final department = controller.department.value;
                final employees = controller.employees.value;
                final teams = controller.teams.value;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDepartmentHeader(department, controller.employeesCount, controller.teamsCount),
                      const SizedBox(height: 24),
                      _buildTeamsSection(teams, controller),
                      const SizedBox(height: 24),
                      _buildEmployeesSection(employees, controller),
                    ],
                  ),
                );
              });
            },
          ),
        ),

        // Effect status bar at bottom
        _buildEffectStatusBar(),
      ],
    );
  }

  Widget _buildEffectStatusBar() {
    return ZenBuilder<DepartmentDetailController>(
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Text(
                'Effects:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              _buildEffectIndicator('Dept', controller.loadDepartmentEffect),
              const SizedBox(width: 8),
              _buildEffectIndicator('Employees', controller.loadEmployeesEffect),
              const SizedBox(width: 8),
              _buildEffectIndicator('Teams', controller.loadTeamsEffect),
              const SizedBox(width: 8),
              _buildEffectIndicator('Refresh', controller.refreshEffect),
              const SizedBox(width: 8),
              _buildEffectIndicator('Nav', controller.navigationEffect),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEffectIndicator(String label, ZenEffect effect) {
    return Obx(() {
      Color color;
      IconData icon;

      if (effect.isLoading.value) {
        color = Colors.orange;
        icon = Icons.sync;
      } else if (effect.error.value != null) {
        color = Colors.red;
        icon = Icons.error_outline;
      } else if (effect.dataWasSet.value) {
        color = Colors.green;
        icon = Icons.check_circle_outline;
      } else {
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDepartmentHeader(Department? department, int employeeCount, int teamCount) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              department?.name ?? 'Unknown Department',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              department?.description ?? 'No description available',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  Icons.people,
                  'Employees: $employeeCount',
                ),
                const SizedBox(width: 16),
                _buildInfoChip(
                  Icons.groups,
                  'Teams: $teamCount',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.blue.shade700),
      label: Text(label, style: TextStyle(color: Colors.black)),
      backgroundColor: Colors.blue.shade50,
    );
  }

  Widget _buildTeamsSection(List<Team> teams, DepartmentDetailController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Teams',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Teams effect indicator
            ZenEffectBuilder<List<Team>>(
              effect: controller.loadTeamsEffect,
              onInitial: () => const SizedBox.shrink(),
              onLoading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              onSuccess: (teams) => Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
              onError: (error) => Icon(Icons.error, size: 16, color: Colors.red.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (teams.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No teams in this department'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: teams.length,
            itemBuilder: (context, index) {
              final team = teams[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    team.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Team ID: ${team.id}'),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.groups, color: Colors.blue),
                  ),
                  // trailing: ZenEffectBuilder<void>(
                  //   effect: controller.navigationEffect,
                  //   onInitial: () => const Icon(Icons.arrow_forward_ios, size: 16),
                  //   onLoading: () => const SizedBox(
                  //     width: 16,
                  //     height: 16,
                  //     child: CircularProgressIndicator(strokeWidth: 2),
                  //   ),
                  //   onSuccess: (_) => const Icon(Icons.arrow_forward_ios, size: 16),
                  //   onError: (_) => Icon(Icons.error, size: 16, color: Colors.red.shade600),
                  // ),
                 // onTap: () => controller.navigateToTeamDetail(team.id),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmployeesSection(
      List<Employee> employees, DepartmentDetailController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Employees',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Employees effect indicator
            ZenEffectBuilder<List<Employee>>(
              effect: controller.loadEmployeesEffect,
              onInitial: () => const SizedBox.shrink(),
              onLoading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              onSuccess: (employees) => Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
              onError: (error) => Icon(Icons.error, size: 16, color: Colors.red.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (employees.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No employees in this department'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    employee.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(employee.position),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  trailing: ZenEffectBuilder<void>(
                    effect: controller.navigationEffect,
                    onInitial: () => const Icon(Icons.arrow_forward_ios, size: 16),
                    onLoading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    onSuccess: (_) => const Icon(Icons.arrow_forward_ios, size: 16),
                    onError: (_) => Icon(Icons.error, size: 16, color: Colors.red.shade600),
                  ),
                  onTap: () => controller.navigateToEmployeeProfile(employee.id),
                ),
              );
            },
          ),
      ],
    );
  }
}