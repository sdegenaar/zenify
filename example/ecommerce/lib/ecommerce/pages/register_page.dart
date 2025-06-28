import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../controllers/register_controller.dart';
import '../routes/app_routes.dart';

/// Registration page for the e-commerce app
class RegisterPage extends ZenView<RegisterController> {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo and welcome text
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_bag,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Account',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to start shopping',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Form error message
              Obx(() => controller.formError.value != null
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.formError.value!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink()),
              
              // Name field
              Obx(() => TextField(
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person),
                  errorText: controller.nameError.value,
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onChanged: controller.setName,
              )),
              
              const SizedBox(height: 16),
              
              // Email field
              Obx(() => TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(Icons.email),
                  errorText: controller.emailError.value,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onChanged: controller.setEmail,
              )),
              
              const SizedBox(height: 16),
              
              // Password field
              Obx(() => TextField(
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock),
                  errorText: controller.passwordError.value,
                ),
                obscureText: true,
                textInputAction: TextInputAction.next,
                onChanged: controller.setPassword,
              )),
              
              const SizedBox(height: 16),
              
              // Confirm password field
              Obx(() => TextField(
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: 'Confirm your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: controller.confirmPasswordError.value,
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onChanged: controller.setConfirmPassword,
              )),
              
              const SizedBox(height: 16),
              
              // Terms and conditions checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() => Checkbox(
                    value: controller.agreeToTerms.value,
                    onChanged: (value) => controller.toggleAgreeToTerms(),
                  )),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'I agree to the Terms of Service and Privacy Policy',
                        ),
                        Obx(() => controller.termsError.value != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  controller.termsError.value!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink()),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Register button
              Obx(() => ElevatedButton(
                onPressed: controller.isLoading.value
                    ? null
                    : () => _register(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: controller.isLoading.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              )),
              
              const SizedBox(height: 16),
              
              // Login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Social signup options
              Column(
                children: [
                  const Text(
                    'Or sign up with',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        context,
                        icon: Icons.g_mobiledata,
                        color: Colors.red,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Google signup not implemented in this demo'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        context,
                        icon: Icons.facebook,
                        color: Colors.blue,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Facebook signup not implemented in this demo'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        context,
                        icon: Icons.apple,
                        color: Colors.black,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Apple signup not implemented in this demo'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          icon,
          color: color,
          size: 28,
        ),
      ),
    );
  }

  Future<void> _register(BuildContext context) async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    
    final success = await controller.register();
    
    if (success && context.mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate to home page
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }
}