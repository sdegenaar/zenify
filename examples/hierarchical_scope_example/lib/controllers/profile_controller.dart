import 'package:zenify/zenify.dart';
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
    ZenLogger.logDebug('Initializing ProfileController');
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
        ZenLogger.logWarning('Failed to load user profile');
      }
    } catch (e) {
      error = e.toString();
      ZenLogger.logError('Error loading profile', e);
    } finally {
      isLoading = false;
      if (user != null) {
        ZenLogger.logDebug('Profile loaded successfully: ${user!.fullName}');
      }
      update();
    }
  }

  Future<void> logout() async {
    isLoading = true;
    update();

    try {
      await profileRepository.logout();
      ZenLogger.logDebug('User logged out successfully');
    } catch (e) {
      error = e.toString();
      ZenLogger.logError('Error during logout', e);
    } finally {
      isLoading = false;
      update();
    }
  }
}