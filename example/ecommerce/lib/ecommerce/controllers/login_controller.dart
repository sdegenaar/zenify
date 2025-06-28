import 'package:zenify/zenify.dart';
import '../../shared/services/auth_service.dart';

/// Controller for the login page
class LoginController extends ZenController {
  final AuthService authService;

  // Observable form state
  final email = ''.obs();
  final password = ''.obs();
  final rememberMe = false.obs();

  // Observable validation state - using nullable type aliases
  final emailError = RxnString(null);
  final passwordError = RxnString(null);
  final formError = RxnString(null);

  // Observable loading state
  final isLoading = false.obs();

  /// Constructor
  LoginController({required this.authService});

  @override
  void onInit() {
    super.onInit();

    // Set up workers to validate form fields
    ZenWorkers.debounce(
      email,
          (_) => validateEmail(),
      const Duration(milliseconds: 500),
    );

    ZenWorkers.debounce(
      password,
          (_) => validatePassword(),
      const Duration(milliseconds: 500),
    );
  }

  /// Validate email
  bool validateEmail() {
    if (email.value.isEmpty) {
      emailError.value = 'Email is required';
      return false;
    }

    if (!email.value.contains('@') || !email.value.contains('.')) {
      emailError.value = 'Enter a valid email address';
      return false;
    }

    emailError.value = null;
    return true;
  }

  /// Validate password
  bool validatePassword() {
    if (password.value.isEmpty) {
      passwordError.value = 'Password is required';
      return false;
    }

    if (password.value.length < 6) {
      passwordError.value = 'Password must be at least 6 characters';
      return false;
    }

    passwordError.value = null;
    return true;
  }

  /// Validate the entire form
  bool validateForm() {
    final isEmailValid = validateEmail();
    final isPasswordValid = validatePassword();

    return isEmailValid && isPasswordValid;
  }

  /// Set email
  void setEmail(String value) {
    email.value = value.trim();
  }

  /// Set password
  void setPassword(String value) {
    password.value = value;
  }

  /// Toggle remember me
  void toggleRememberMe() {
    rememberMe.value = !rememberMe.value;
  }

  /// Login with email and password
  Future<bool> login() async {
    // Clear previous form error
    formError.value = null;

    // Validate form
    if (!validateForm()) {
      return false;
    }

    isLoading.value = true;

    try {
      // Attempt to login
      await authService.login(email.value, password.value);
      return true;
    } catch (e) {
      // Set form error
      formError.value = e.toString();
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Reset the form
  void resetForm() {
    email.value = '';
    password.value = '';
    rememberMe.value = false;
    emailError.value = null;
    passwordError.value = null;
    formError.value = null;
  }
}