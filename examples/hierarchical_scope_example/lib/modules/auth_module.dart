import 'package:zenify/zenify.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import '../services/profile_repository.dart';
import 'network_module.dart';

class AuthModule extends ZenModule {
  @override
  String get name => 'AuthModule';

  @override
  List<ZenModule> get dependencies => [NetworkModule()];

  @override
  void register(ZenScope scope) {
    // Get the network service from the network module
    final networkService = Zen.lookup<NetworkService>(scope: scope);
    if (networkService == null) {
      ZenLogger.logError('NetworkService not found, cannot initialize AuthModule');
      return;
    }

    // Register auth service if not already registered
    if (Zen.lookup<AuthService>(scope: scope) == null) {
      Zen.inject<AuthService>(
          AuthService(networkService: networkService),
          scope: scope
      );
    }

    // Register profile repository if not already registered
    if (Zen.lookup<ProfileRepository>(scope: scope) == null) {
      final authService = Zen.lookup<AuthService>(scope: scope);
      if (authService != null) {
        Zen.inject<ProfileRepository>(
            ProfileRepository(authService: authService),
            scope: scope
        );
      } else {
        ZenLogger.logError('AuthService not found, cannot initialize ProfileRepository');
      }
    }
  }

  @override
  void onInit(ZenScope scope) {
    super.onInit(scope);
    ZenLogger.logDebug('AuthModule initialized');
  }

  @override
  void onDispose(ZenScope scope) {
    super.onDispose(scope);
    ZenLogger.logDebug('AuthModule disposed');
  }
}