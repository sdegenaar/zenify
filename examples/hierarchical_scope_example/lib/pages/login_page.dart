import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/login_controller.dart';
import 'profile_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return ZenScopeWidget(
      name: 'LoginScope',
      child: Builder(
        builder: (scopeContext) {
          // Access the login scope
          final loginScope = ZenScopeWidget.of(scopeContext);

          // Create and register the controller
          final controller = LoginController(scope: loginScope);
          Zen.put<LoginController>(controller, scope: loginScope);

          return Scaffold(
            appBar: AppBar(
              title: const Text('Login'),
            ),
            body: ZenBuilder<LoginController>(
              findScopeFn: () => loginScope,
              builder: (controller) {
                // Navigation logic
                if (controller.isAuthenticated) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                  });
                }

                // UI
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(labelText: 'Username'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      if (controller.isLoading)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: () {
                            controller.login(
                              usernameController.text,
                              passwordController.text,
                            );
                          },
                          child: const Text('Login'),
                        ),
                      if (controller.error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            controller.error,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const SizedBox(height: 32),
                      const Text('Hint: use "user" / "pass" to login'),
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

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}