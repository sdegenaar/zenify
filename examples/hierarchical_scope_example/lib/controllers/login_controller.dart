
import 'package:zen_state/zen_state.dart';
import '../services/auth_service.dart';

class LoginController extends ZenController {
  // Declare dependencies
  final AuthService? authService;

  // Constructor with scope
  LoginController({ZenScope? scope})
      : authService = Zen.findDependency<AuthService>(scope: scope);

  // State variables
  bool isLoading = false;
  String error = '';
  bool isAuthenticated = false;

  // Login method
  Future<void> login(String username, String password) async {
    if (authService == null) {
      error = 'Auth service not available';
      update();
      return;
    }

    error = '';
    isLoading = true;
    update();

    try {
      isAuthenticated = await authService!.login(username, password);
      if (!isAuthenticated) {
        error = 'Invalid credentials';
      }
    } catch (e) {
      error = e.toString();
      isAuthenticated = false;
    } finally {
      isLoading = false;
      update();
    }
  }

  @override
  void onDispose() {
    // Clean up any resources
    super.onDispose();
  }
}