import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../../../shared/models/employee.dart';
import '../../../shared/widgets/debug_dialog.dart';
import '../controllers/employee_profile_controller.dart';

/// Employee profile page using ZenView pattern with ZenEffects and ZenEffectBuilder
class EmployeeProfilePage extends ZenView<EmployeeProfileController> {
  final String employeeId;
  final String departmentId;

  const EmployeeProfilePage({
    required this.employeeId,
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
      title: ZenBuilder<EmployeeProfileController>(
        builder: (context, controller) {
          return Obx(() {
            final employee = controller.employee.value;
            return Text(employee?.name ?? 'Employee Profile');
          });
        },
      ),
      backgroundColor: Colors.blue.shade700,
      foregroundColor: Colors.white,
      elevation: 2,
      actions: [
        ZenBuilder<EmployeeProfileController>(
          builder: (context, controller) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Refresh button with ZenEffectBuilder
                ZenEffectBuilder<bool>(
                  effect: controller.refreshEffect,
                  onInitial: () => IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: controller.refreshEmployeeProfile,
                    tooltip: 'Refresh Profile',
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
                    onPressed: controller.refreshEmployeeProfile,
                    tooltip: 'Refresh Profile',
                  ),
                  onError: (error) => IconButton(
                    icon: Icon(Icons.refresh, color: Colors.red.shade300),
                    onPressed: controller.refreshEmployeeProfile,
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
        ZenBuilder<EmployeeProfileController>(
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
          child: ZenBuilder<EmployeeProfileController>(
            builder: (context, controller) {
              return Obx(() {
                ZenLogger.logInfo('Building body - Loading: ${controller.isLoading.value}, Employee: ${controller.employee.value?.name}');

                if (controller.isLoading.value) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading employee profile...'),
                      ],
                    ),
                  );
                }

                final employee = controller.employee.value;
                final activities = controller.activities.value;

                if (employee == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Employee not found'),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEmployeeHeader(employee),
                      const SizedBox(height: 24),
                      _buildEmployeeDetails(employee),
                      const SizedBox(height: 24),
                      _buildSkillsSection(employee),
                      const SizedBox(height: 24),
                      _buildProjectsSection(employee),
                      const SizedBox(height: 24),
                      _buildActivitiesSection(activities, controller),
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
    return ZenBuilder<EmployeeProfileController>(
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
              _buildEffectIndicator('Employee', controller.loadEmployeeEffect),
              const SizedBox(width: 8),
              _buildEffectIndicator('Activities', controller.loadActivitiesEffect),
              const SizedBox(width: 8),
              _buildEffectIndicator('Refresh', controller.refreshEffect),
              const SizedBox(width: 8),
              _buildEffectIndicator('Navigation', controller.navigationEffect),
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

  Widget _buildEmployeeHeader(Employee employee) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue.shade100,
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.position,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(Icons.business, size: 16, color: Colors.blue.shade700),
                    label: Text('Department: ${employee.departmentId}',style: TextStyle(color: Colors.black)),
                    backgroundColor: Colors.blue.shade50,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeDetails(Employee employee) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.email, 'Email', employee.email),
            const Divider(),
            _buildDetailRow(Icons.phone, 'Phone', employee.phone ?? 'No phone'),
            const Divider(),
            _buildDetailRow(Icons.calendar_today, 'Hire Date', employee.hireDate),
            const Divider(),
            _buildDetailRow(Icons.location_on, 'Address', employee.address ?? 'No address'),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection(Employee employee) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skills',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (employee.skills.isEmpty)
              const Text('No skills listed')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: employee.skills
                    .map((skill) => Chip(
                  label: Text(skill, style: TextStyle(color: Colors.black)),
                  backgroundColor: Colors.green.shade50,
                ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsSection(Employee employee) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Projects',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (employee.projects.isEmpty)
              const Text('No projects assigned')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: employee.projects.length,
                itemBuilder: (context, index) {
                  final project = employee.projects[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        project.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Role: ${project.role}'),
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Icon(
                          Icons.work,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesSection(List<Map<String, dynamic>> activities, EmployeeProfileController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Activities (${activities.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Activities effect indicator
            ZenEffectBuilder<List<Map<String, dynamic>>>(
              effect: controller.loadActivitiesEffect,
              onInitial: () => const SizedBox.shrink(),
              onLoading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              onSuccess: (activities) => Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
              onError: (error) => Icon(Icons.error, size: 16, color: Colors.red.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recent activities'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    activity['description'] as String? ?? 'Unknown Activity',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Type: ${activity['type'] as String? ?? 'Unknown'}',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity['timestamp'] as String? ?? 'Unknown date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      _getActivityIcon(activity['type'] as String? ?? ''),
                      color: Colors.blue,
                      size: 16,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'task':
      case 'task_completed':
        return Icons.task;
      case 'meeting':
        return Icons.people;
      case 'project':
        return Icons.work;
      case 'training':
        return Icons.school;
      case 'login':
        return Icons.login;
      default:
        return Icons.event_note;
    }
  }
}