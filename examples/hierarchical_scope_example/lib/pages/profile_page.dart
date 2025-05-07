
import 'package:flutter/material.dart';
import 'package:zen_state/zen_state.dart';
import '../controllers/profile_controller.dart';
import '../services/profile_repository.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZenScopeWidget(
      name: 'ProfileScope',
      child: Builder(
        builder: (scopeContext) {
          // Get the profile scope
          final profileScope = ZenScopeWidget.of(scopeContext);

          // Get the root app scope - this will have our dependencies
          final appScope = ZenScopeWidget.of(context, findRoot: true);

          // Check if we have the necessary dependencies in the app scope
          final authService = Zen.findDependency<AuthService>(scope: appScope);

          if (authService == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Profile')),
              body: const Center(
                child: Text('App configuration error: AuthService not available'),
              ),
            );
          }

          // Create and register ProfileRepository if needed
          ProfileRepository profileRepo;
          final existingRepo = Zen.findDependency<ProfileRepository>(scope: appScope);

          if (existingRepo != null) {
            profileRepo = existingRepo;
          } else {
            // Create a new repository and register it
            profileRepo = ProfileRepository(authService: authService);
            Zen.putDependency<ProfileRepository>(profileRepo, scope: appScope);
          }

          // Create and register the controller with the profile scope
          final controller = ProfileController(scope: appScope);
          Zen.put<ProfileController>(controller, scope: profileScope);

          return Scaffold(
            appBar: AppBar(
              title: const Text('Profile'),
              automaticallyImplyLeading: false,
            ),
            body: ZenBuilder<ProfileController>(
              findScopeFn: () => profileScope,
              builder: (controller) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.error.isNotEmpty) {
                  return Center(
                    child: Text(
                      'Error: ${controller.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final user = controller.user;
                if (user == null) {
                  return const Center(child: Text('No user data available'));
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'User Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProfileItem('Full Name', user.fullName),
                      _buildProfileItem('Username', user.username),
                      _buildProfileItem('Email', user.email),
                      _buildProfileItem('ID', user.id),
                      const SizedBox(height: 32),
                      Center(
                        child: ElevatedButton(
                          onPressed: () async {
                            await controller.logout();
                            if (context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (_) => const LoginPage()),
                              );
                            }
                          },
                          child: const Text('Logout'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }
}