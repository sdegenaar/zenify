import 'package:zenify/zenify.dart';
import '../../shared/services/auth_service.dart';

/// Controller for the registration page
class RegisterController extends ZenController {
  final AuthService authService;

  // Observable form state
  final name = ''.obs();
  final email = ''.obs();
  final password = ''.obs();
  final confirmPassword = ''.obs();
  final agreeToTerms = false.obs();

  // Observable validation state
  final nameError = Rx<String?>(null);
  final emailError = Rx<String?>(null);
  final passwordError = Rx<String?>(null);
  final confirmPasswordError = Rx<String?>(null);
  final termsError = Rx<String?>(null);
  final formError = Rx<String?>(null);

  // Observable loading state
  final isLoading = false.obs();

  /// Constructor
  RegisterController({required this.authService});

  @override
  void onInit() {
    super.onInit();

    // Set up workers to validate form fields
    ZenWorkers.debounce(
      name,
      (_) => validateName(),
      const Duration(milliseconds: 500),
    );

    ZenWorkers.debounce(
      email,
      (_) => validateEmail(),
      const Duration(milliseconds: 500),
    );

    ZenWorkers.debounce(
      password,
      (_) {
        validatePassword();
        validateConfirmPassword();
      },
      const Duration(milliseconds: 500),
    );

    ZenWorkers.debounce(
      confirmPassword,
      (_) => validateConfirmPassword(),
      const Duration(milliseconds: 500),
    );

    ZenWorkers.ever(agreeToTerms, (_) => validateTerms());
  }

  /// Validate name
  bool validateName() {
    if (name.value.isEmpty) {
      nameError.value = 'Name is required';
      return false;
    }

    if (name.value.length < 2) {
      nameError.value = 'Name must be at least 2 characters';
      return false;
    }

    nameError.value = null;
    return true;
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

  /// Validate confirm password
  bool validateConfirmPassword() {
    if (confirmPassword.value.isEmpty) {
      confirmPasswordError.value = 'Please confirm your password';
      return false;
    }

    if (confirmPassword.value != password.value) {
      confirmPasswordError.value = 'Passwords do not match';
      return false;
    }

    confirmPasswordError.value = null;
    return true;
  }

  /// Validate terms agreement
  bool validateTerms() {
    if (!agreeToTerms.value) {
      termsError.value = 'You must agree to the terms';
      return false;
    }

    termsError.value = null;
    return true;
  }

  /// Validate the entire form
  bool validateForm() {
    final isNameValid = validateName();
    final isEmailValid = validateEmail();
    final isPasswordValid = validatePassword();
    final isConfirmPasswordValid = validateConfirmPassword();
    final isTermsValid = validateTerms();

    return isNameValid &&
        isEmailValid &&
        isPasswordValid &&
        isConfirmPasswordValid &&
        isTermsValid;
  }

  /// Set name
  void setName(String value) {
    name.value = value.trim();
  }

  /// Set email
  void setEmail(String value) {
    email.value = value.trim();
  }

  /// Set password
  void setPassword(String value) {
    password.value = value;
  }

  /// Set confirm password
  void setConfirmPassword(String value) {
    confirmPassword.value = value;
  }

  /// Toggle agree to terms
  void toggleAgreeToTerms() {
    agreeToTerms.value = !agreeToTerms.value;
  }

  /// Register a new user
  Future<bool> register() async {
    // Clear previous form error
    formError.value = null;

    // Validate form
    if (!validateForm()) {
      return false;
    }

    isLoading.value = true;

    try {
      // Attempt to register
      await authService.register(name.value, email.value, password.value);
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
    name.value = '';
    email.value = '';
    password.value = '';
    confirmPassword.value = '';
    agreeToTerms.value = false;
    nameError.value = null;
    emailError.value = null;
    passwordError.value = null;
    confirmPasswordError.value = null;
    termsError.value = null;
    formError.value = null;
  }
}
