import 'package:zen_state/zen_state.dart';
import '../services/profile_repository.dart';
import '../models/user.dart';

class ProfileController extends ZenController {
  // Declare dependencies
  late final ProfileRepository profileRepository;

  // Constructor with scope
  ProfileController({ZenScope? scope}) {
    // Initialize in the constructor body instead of initializer list
    final repo = Zen.findDependency<ProfileRepository>(scope: scope);
    if (repo == null) {
      throw Exception('ProfileRepository not found');
    }
    profileRepository = repo;
  }

  // State variables
  bool isLoading = false;
  String error = '';
  User? user;

  @override
  void onInit() {
    super.onInit();
    print('init profile controller');
    loadProfile();
  }

  Future<void> loadProfile() async {
    isLoading = true;
    error = '';
    update();

    try {
      user = await profileRepository.getUserProfile();
      if (user == null) {
        error = 'Failed to load user profile';
      }
    } catch (e) {
      error = e.toString();
      print('error');
    } finally {
      isLoading = false;
      print('calling update' + user!.fullName);
      update();
    }
  }

  Future<void> logout() async {
    isLoading = true;
    update();

    try {
      await profileRepository.logout();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      update();
    }
  }
}