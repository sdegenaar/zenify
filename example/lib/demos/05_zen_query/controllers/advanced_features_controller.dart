import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class AdvancedFeaturesController extends ZenController {
  late final ZenQuery<User> userQuery;
  late final ZenQuery<String> userEmailQuery;
  late final ZenQuery<List<Post>> userPostsQuery;
  late final ZenQuery<List<User>> searchQuery;
  late final ZenQuery<String> slowQuery;
  late final ZenQuery<User> dedupeQuery;

  final searchController = TextEditingController();
  final searchEnabled = false.obs();
  final searchTerm = ''.obs();
  final fetchCount = 0.obs();

  @override
  void onInit() {
    super.onInit();

    // Base user query
    userQuery = ZenQuery<User>(
      queryKey: 'user:2',
      fetcher: (token) => ApiService.getUser(2, cancelToken: token),
      config: const ZenQueryConfig(staleTime: Duration(minutes: 5)),
    );

    // Derived query - only email
    userEmailQuery = userQuery.select((user) => user.email);

    // Dependent query - waits for user to load
    userPostsQuery = ZenQuery<List<Post>>(
      queryKey: 'posts:user:2',
      fetcher: (token) async {
        // This query only runs if userQuery has data
        if (!userQuery.hasData) {
          throw Exception('User not loaded yet');
        }
        final response = await ApiService.getPosts(
          userId: userQuery.data.value!.id,
          pageSize: 5,
          cancelToken: token,
        );
        return response.items;
      },
      config: const ZenQueryConfig(staleTime: Duration(minutes: 3)),
      enabled: false, // Start disabled
    );

    // Enable userPostsQuery when userQuery has data
    ZenWorkers.ever(userQuery.data, (user) {
      if (user != null && !userPostsQuery.enabled.value) {
        userPostsQuery.enabled.value = true;
      }
    });

    // Conditional search query
    searchQuery = ZenQuery<List<User>>(
      queryKey: 'users:search',
      fetcher: (token) => ApiService.getUsers(search: searchTerm.value),
      config: const ZenQueryConfig(staleTime: Duration(seconds: 30)),
      enabled: false,
    );

    // Update search when term changes
    ZenWorkers.debounce(searchTerm, (term) {
      if (searchEnabled.value && term.isNotEmpty) {
        searchQuery.refetch();
      }
    }, const Duration(milliseconds: 500));

    // Slow query for cancellation demo
    slowQuery = ZenQuery<String>(
      queryKey: 'slow-query',
      fetcher: (token) async {
        await Future.delayed(const Duration(seconds: 3));
        if (token.isCancelled) {
          throw ZenCancellationException('Request cancelled');
        }
        return 'Slow data loaded at ${DateTime.now().toString().split('.').first}';
      },
      config: const ZenQueryConfig(refetchOnMount: RefetchBehavior.never),
    );

    // Deduplication demo query
    dedupeQuery = ZenQuery<User>(
      queryKey: 'dedupe-demo',
      fetcher: (token) async {
        debugPrint('🌐 Making API call to fetch user...');
        return await ApiService.getUser(3, cancelToken: token);
      },
      config: const ZenQueryConfig(
        staleTime: Duration(seconds: 5),
      ),
    );
  }

  void toggleSearch(bool enabled) {
    searchEnabled.value = enabled;
    searchQuery.enabled.value = enabled;
    if (enabled && searchTerm.value.isNotEmpty) {
      searchQuery.fetch();
    }
  }

  void onSearchChanged(String value) {
    searchTerm.value = value;
  }

  void fetchSlow() {
    slowQuery.fetch(force: true);
  }

  void cancelSlow() {
    // Cancellation happens automatically when we force a new fetch
    // or manually by resetting the query
    slowQuery.reset();
  }

  void fetchMultiple() {
    fetchCount.value = 0;

    // Make 5 simultaneous fetches with the same key
    // They will be deduplicated into a single request
    for (var i = 0; i < 5; i++) {
      dedupeQuery.fetch(force: true).then((_) {
        fetchCount.value++;
      });
    }
  }

  @override
  void onClose() {
    // ⭐ NO NEED TO MANUALLY DISPOSE QUERIES ANYMORE!
    // All queries created in onInit() are automatically tracked and disposed
    // when this controller is disposed. This prevents memory leaks without boilerplate.

    // Only dispose non-query resources like text controllers
    searchController.dispose();
    super.onClose();
  }
}
