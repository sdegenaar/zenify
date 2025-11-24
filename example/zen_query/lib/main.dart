import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

// Mock API service
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});
}

class ApiService {
  static Future<User> getUser(int id) async {
    await Future.delayed(const Duration(seconds: 1));
    if (id == 999) {
      throw Exception('User not found');
    }
    return User(id: id, name: 'User $id', email: 'user$id@example.com');
  }

  static Future<List<String>> getPosts(int userId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return ['Post 1', 'Post 2', 'Post 3'];
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Zenify
  Zen.init();

  // Configure for development with detailed logging
  ZenConfig.applyEnvironment(ZenEnvironment.development);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenQuery Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const QueryExamplePage(),
    );
  }
}

// Controller that manages queries
class QueryController extends ZenController {
  // Use regular fields instead of late final to avoid re-initialization errors
  ZenQuery<User>? _userQuery;
  ZenQuery<List<String>>? _postsQuery;

  ZenQuery<User> get userQuery => _userQuery!;
  ZenQuery<List<String>> get postsQuery => _postsQuery!;

  @override
  void onInit() {
    super.onInit();

    // Only initialize if not already initialized
    if (_userQuery == null) {
      // Create user query with caching and auto-refetch
      _userQuery = ZenQuery<User>(
        queryKey: 'user:1',
        fetcher: (token) => ApiService.getUser(1),
        config: const ZenQueryConfig(
          staleTime: Duration(seconds: 30),
          cacheTime: Duration(minutes: 5),
          retryCount: 3,
          refetchInterval: Duration(seconds: 60),
        ),
      );

      // Create posts query
      _postsQuery = ZenQuery<List<String>>(
        queryKey: 'posts:1',
        fetcher: (token) => ApiService.getPosts(1),
        config: const ZenQueryConfig(
          staleTime: Duration(seconds: 20),
        ),
      );

      // Trigger initial fetches
      _userQuery!.fetch();
      _postsQuery!.fetch();
    }
  }

  void refetchAll() {
    userQuery.refetch();
    postsQuery.refetch();
  }

  void invalidateAll() {
    userQuery.invalidate();
    postsQuery.invalidate();
  }

  void optimisticUpdate() {
    final currentUser = userQuery.data.value;
    if (currentUser != null) {
      userQuery.setData(User(
        id: currentUser.id,
        name: '${currentUser.name} (Updated)',
        email: currentUser.email,
      ));
    }
  }

  @override
  void onClose() {
    _userQuery?.dispose();
    _postsQuery?.dispose();
    super.onClose();
  }
}

// View using ZenView pattern
class QueryExamplePage extends ZenView<QueryController> {
  const QueryExamplePage({super.key});

  @override
  QueryController Function()? get createController => () => QueryController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenQuery Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showCacheStats(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Query Section
          _buildSection(
            'User Query',
            ZenQueryBuilder<User>(
              query: controller.userQuery,
              builder: (context, user) {
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(user.id.toString())),
                    title: Text(user.name),
                    subtitle: Text(user.email),
                    trailing: controller.userQuery.isRefetching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, retry) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Posts Query Section
          _buildSection(
            'User Posts',
            ZenQueryBuilder<List<String>>(
              query: controller.postsQuery,
              showStaleData: true,
              builder: (context, posts) {
                return Card(
                  child: Column(
                    children: posts
                        .map((post) => ListTile(
                              leading: const Icon(Icons.article),
                              title: Text(post),
                            ))
                        .toList(),
                  ),
                );
              },
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, retry) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text('Error: $error'),
                      ElevatedButton(
                        onPressed: retry,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          _buildSection(
            'Actions',
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.refetchAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refetch All'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: controller.invalidateAll,
                      icon: const Icon(Icons.clear),
                      label: const Text('Invalidate Cache'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: controller.optimisticUpdate,
                      icon: const Icon(Icons.edit),
                      label: const Text('Optimistic Update'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Status Display
          _buildSection(
            'Query Status',
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Obx(() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User Query: ${controller.userQuery.status.value}'),
                      Text(
                          'Is Loading: ${controller.userQuery.isLoading.value}'),
                      Text('Has Data: ${controller.userQuery.hasData}'),
                      Text('Is Stale: ${controller.userQuery.isStale}'),
                      Text(
                          'Is Refetching: ${controller.userQuery.isRefetching}'),
                      const Divider(),
                      Text(
                          'Posts Query: ${controller.postsQuery.status.value}'),
                      Text(
                          'Is Loading: ${controller.postsQuery.isLoading.value}'),
                      Text('Has Data: ${controller.postsQuery.hasData}'),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  void _showCacheStats(BuildContext context) {
    final stats = ZenQueryCache.instance.getStats();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Queries: ${stats['activeQueries']}'),
            Text('Cached Entries: ${stats['cachedEntries']}'),
            Text('Pending Fetches: ${stats['pendingFetches']}'),
            const Divider(),
            const Text('Query Keys:'),
            ...List<String>.from(stats['queries'])
                .map((key) => Text('  • $key')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
