import 'package:zenify/zenify.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class QueryBasicsController extends ZenController {
  late final ZenQuery<User> userQuery;
  late final ZenQuery<List<Post>> postsQuery;

  // Reactive cache stats
  final cacheStats = Rx<Map<String, dynamic>>({});

  @override
  void onInit() {
    super.onInit();

    // Create user query with caching
    userQuery = ZenQuery<User>(
      queryKey: 'user:1',
      fetcher: (token) => ApiService.getUser(1, cancelToken: token),
      config: const ZenQueryConfig(
        staleTime: Duration(seconds: 30),
        cacheTime: Duration(minutes: 5),
        retryCount: 3,
        retryDelay: Duration(seconds: 1),
        exponentialBackoff: true,
        refetchOnMount: true,
        refetchOnFocus: true,
      ),
    );

    // Create posts query with placeholder data
    postsQuery = ZenQuery<List<Post>>(
      queryKey: 'posts:featured',
      fetcher: (token) async {
        final response =
            await ApiService.getPosts(page: 1, pageSize: 5, cancelToken: token);
        return response.items;
      },
      config: ZenQueryConfig(
        staleTime: const Duration(seconds: 20),
        cacheTime: const Duration(minutes: 3),
        retryCount: 2,
        // Placeholder data to show while loading
        placeholderData: [
          Post(
            id: 0,
            userId: 0,
            title: 'Loading...',
            content: 'Fetching latest posts...',
            createdAt: DateTime.now(),
            likes: 0,
          ),
        ],
      ),
    );
  }

  void refetchAll() {
    userQuery.refetch();
    postsQuery.refetch();
  }

  void invalidateAll() {
    userQuery.invalidate();
    postsQuery.invalidate();
  }

  void resetAll() {
    userQuery.reset();
    postsQuery.reset();
  }

  void clearCache() {
    ZenQueryCache.instance.clear();
  }

  @override
  void onClose() {
    userQuery.dispose();
    postsQuery.dispose();
    super.onClose();
  }
}
