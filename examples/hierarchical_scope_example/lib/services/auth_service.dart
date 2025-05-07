import 'network_service.dart';

class AuthService {
  final NetworkService networkService;
  String? _token;

  AuthService({required this.networkService});

  String? get token => _token;
  bool get isLoggedIn => _token != null;

  Future<bool> login(String username, String password) async {
    try {
      final response = await networkService.post('/login', {
        'username': username,
        'password': password,
      });

      if (response['success'] == true) {
        _token = response['token'];
        return true;
      }
      return false;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await networkService.post('/logout', {});
      _token = null;
    } catch (e) {
      rethrow;
    }
  }
}