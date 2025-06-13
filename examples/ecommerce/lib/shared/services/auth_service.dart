import 'package:zenify/zenify.dart';
import '../models/user_model.dart';

/// Service for managing authentication in the e-commerce app
class AuthService {
  // Observable current user
  final currentUser = Rx<User?>(null);

  // Observable authentication state
  final isAuthenticated = false.obs();

  // Observable loading state
  final isLoading = false.obs();

  // ZenEffect for authentication operations
  late final ZenEffect<User?> authEffect;

  /// Constructor
  AuthService() {
    // Initialize effect first
    authEffect = createEffect<User?>(name: 'auth');

    // Set up worker to update authentication state when user changes
    ZenWorkers.ever(currentUser, (user) {
      isAuthenticated.value = user != null;
    });
  }


  /// Login with email and password
  Future<User> login(String email, String password) async {
    isLoading.value = true;

    try {
      // Set effect to loading state
      authEffect.loading();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Validate credentials (mock implementation)
      if (email.isEmpty || !email.contains('@') || password.length < 6) {
        throw Exception('Invalid credentials');
      }

      // Create mock user
      final user = User(
        id: '1',
        email: email,
        name: email.split('@').first,
        favoriteProductIds: [],
      );

      // Update current user
      currentUser.value = user;

      // Set effect to success state
      authEffect.success(user);

      return user;
    } catch (e) {
      // Set effect to error state
      authEffect.setError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Register a new user
  Future<User> register(String name, String email, String password) async {
    isLoading.value = true;

    try {
      // Set effect to loading state
      authEffect.loading();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Validate input (mock implementation)
      if (name.isEmpty || email.isEmpty || !email.contains('@') || password.length < 6) {
        throw Exception('Invalid registration data');
      }

      // Create mock user
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        email: email,
        name: name,
        favoriteProductIds: [],
      );

      // Update current user
      currentUser.value = user;

      // Set effect to success state
      authEffect.success(user);

      return user;
    } catch (e) {
      // Set effect to error state
      authEffect.setError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    isLoading.value = true;

    try {
      // Set effect to loading state
      authEffect.loading();

      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear current user
      currentUser.value = null;

      // Set effect to success state
      authEffect.success(null);
    } catch (e) {
      // Set effect to error state
      authEffect.setError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update user profile
  Future<User> updateProfile(String name, {String? avatarUrl}) async {
    isLoading.value = true;

    try {
      // Set effect to loading state
      authEffect.loading();

      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // Validate input
      if (name.isEmpty) {
        throw Exception('Name cannot be empty');
      }

      // Check if user is authenticated
      final user = currentUser.value;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Update user
      final updatedUser = user.copyWith(
        name: name,
        avatarUrl: avatarUrl ?? user.avatarUrl,
      );

      // Update current user
      currentUser.value = updatedUser;

      // Set effect to success state
      authEffect.success(updatedUser);

      return updatedUser;
    } catch (e) {
      // Set effect to error state
      authEffect.setError(e);
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  /// Toggle favorite status for a product
  Future<void> toggleFavorite(String productId) async {
    // Check if user is authenticated
    final user = currentUser.value;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    // Toggle favorite
    final updatedUser = user.toggleFavorite(productId);

    // Update current user
    currentUser.value = updatedUser;
  }

  /// Check if a product is in favorites
  bool isFavorite(String productId) {
    final user = currentUser.value;
    if (user == null) {
      return false;
    }

    return user.favoriteProductIds.contains(productId);
  }
}
