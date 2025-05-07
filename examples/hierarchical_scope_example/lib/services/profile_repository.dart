import 'auth_service.dart';
import '../models/user.dart';

class ProfileRepository {
  final AuthService authService;

  ProfileRepository({required this.authService});

  Future<User> getUserProfile() async {
    print('get progile');
    if (!authService.isLoggedIn) {
      throw Exception('Not authenticated');
    }

    // In a real app, we would fetch user profile from an API
    // For this example, we'll return a mock user
    await Future.delayed(const Duration(milliseconds: 500));
    return User.mock();
  }

  Future<void> logout() async {
    await authService.logout();
  }
}