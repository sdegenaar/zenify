import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.reset();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQuery invalidate()', () {
    test('invalidate() triggers refetch for active query', () async {
      var fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-invalidate',
        fetcher: (token) async {
          fetchCount++;
          await Future.delayed(Duration(milliseconds: 10));
          return 'data-$fetchCount';
        },
      );

      // Initial fetch
      await query.fetch();
      expect(fetchCount, 1);
      expect(query.data.value, 'data-1');

      // Wait a bit to ensure query is not loading
      await Future.delayed(Duration(milliseconds: 20));

      // Invalidate should trigger automatic refetch
      query.invalidate();

      // Wait for refetch to complete
      await Future.delayed(Duration(milliseconds: 50));

      expect(fetchCount, 2); // Should have refetched
      expect(query.data.value, 'data-2');
    });

    test('invalidate() does not refetch if query is disabled', () async {
      var fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-invalidate-disabled',
        fetcher: (token) async {
          fetchCount++;
          return 'data-$fetchCount';
        },
        enabled: false,
      );

      // Manually fetch once
      query.enabled.value = true;
      await query.fetch();
      query.enabled.value = false;

      expect(fetchCount, 1);

      // Invalidate should NOT refetch because query is disabled
      query.invalidate();
      await Future.delayed(Duration(milliseconds: 50));

      expect(fetchCount, 1); // Should not have refetched
    });

    test('invalidate() does not refetch if query is already loading', () async {
      var fetchCount = 0;

      final query = ZenQuery<String>(
        queryKey: 'test-invalidate-loading',
        fetcher: (token) async {
          fetchCount++;
          await Future.delayed(Duration(milliseconds: 100));
          return 'data-$fetchCount';
        },
      );

      // Start a fetch (don't await)
      query.fetch();
      await Future.delayed(Duration(milliseconds: 10));

      expect(query.isLoading.value, true);
      expect(fetchCount, 1);

      // Invalidate while loading should NOT trigger another fetch
      query.invalidate();
      await Future.delayed(Duration(milliseconds: 20));

      expect(fetchCount, 1); // Should not have triggered another fetch

      // Wait for original fetch to complete
      await Future.delayed(Duration(milliseconds: 100));
      expect(fetchCount, 1);
    });

    test('invalidate() marks query as stale', () async {
      final query = ZenQuery<String>(
        queryKey: 'test-invalidate-stale',
        fetcher: (token) async => 'data',
        config: ZenQueryConfig(
          staleTime: Duration(hours: 1), // Long stale time
        ),
      );

      await query.fetch();
      expect(query.isStale, false); // Fresh data

      query.invalidate();

      // Should be marked as stale (even before refetch completes)
      expect(query.isStale, true);
    });

    test('invalidate() works with mutations (common use case)', () async {
      var posts = ['post1', 'post2'];

      final postsQuery = ZenQuery<List<String>>(
        queryKey: 'posts',
        fetcher: (token) async => List.from(posts),
      );

      final createPostMutation = ZenMutation<String, String>(
        mutationFn: (content) async {
          posts.add(content);
          return content;
        },
        onSuccess: (_, __, ___) {
          postsQuery.invalidate(); // Should trigger refetch
        },
      );

      // Initial fetch
      await postsQuery.fetch();
      expect(postsQuery.data.value, ['post1', 'post2']);

      // Create new post
      await createPostMutation.mutate('post3');

      // Wait for invalidate refetch
      await Future.delayed(Duration(milliseconds: 50));

      // Posts query should have automatically refetched
      expect(postsQuery.data.value, ['post1', 'post2', 'post3']);
    });
  });
}
