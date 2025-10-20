import 'package:zenify/zenify.dart';
import '../../shared/services/auth_service.dart';
import '../controllers/login_controller.dart';
import '../controllers/register_controller.dart';

/// Module for authentication-related features
class AuthModule extends ZenModule {
  @override
  String get name => 'AuthModule';

  @override
  void register(ZenScope scope) {
    // Find the AuthService from the parent scope
    final authService = Zen.find<AuthService>();

    // Register controllers for this module
    scope.putLazy<LoginController>(
      () => LoginController(authService: authService),
    );

    scope.putLazy<RegisterController>(
      () => RegisterController(authService: authService),
    );
  }

  @override
  Future<void> onInit(ZenScope scope) async {
    ZenLogger.logInfo('AuthModule initialized');
  }

  @override
  Future<void> onDispose(ZenScope scope) async {
    ZenLogger.logInfo('AuthModule disposed');
  }
}
