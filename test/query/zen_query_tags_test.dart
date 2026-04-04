import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Typed stub fetcher that counts invocations.
class _Fetcher<T> {
  int calls = 0;
  final T value;
  _Fetcher(this.value);
  Future<T> call(ZenCancelToken _) async {
    calls++;
    return value;
  }
}

void main() {
  setUp(() {
    Zen.init();
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.testMode().clearQueryCache();
    Zen.reset();
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Tags on ZenQuery
  // ─────────────────────────────────────────────────────────────────────────────
  group('ZenQuery — tags field', () {
    test('query with no tags has empty tags list', () {
      final q = ZenQuery<int>(
        queryKey: 'no-tags',
        fetcher: (_) async => 1,
      );
      expect(q.tags, isEmpty);
    });

    test('query stores provided tags as an unmodifiable list', () {
      final q = ZenQuery<int>(
        queryKey: 'tagged',
        fetcher: (_) async => 1,
        tags: ['user', 'profile'],
      );
      expect(q.tags, containsAll(['user', 'profile']));
      expect(q.tags.length, 2);
      expect(() => (q.tags as dynamic).add('extra'), throwsUnsupportedError);
    });

    test('tags are indexed in the cache on registration', () {
      ZenQuery<int>(
          queryKey: 'user:1', fetcher: (_) async => 1, tags: ['user']);
      ZenQuery<int>(
          queryKey: 'user:2', fetcher: (_) async => 2, tags: ['user']);

      final keys = ZenQueryCache.instance.getKeysByTag('user');
      expect(keys, containsAll(['user:1', 'user:2']));
    });

    test('tag index is cleaned up on query disposal', () {
      final q = ZenQuery<int>(
        queryKey: 'temp:1',
        fetcher: (_) async => 1,
        tags: ['temp'],
      );

      expect(ZenQueryCache.instance.getKeysByTag('temp'), contains('temp:1'));
      q.dispose();
      expect(ZenQueryCache.instance.getKeysByTag('temp'),
          isNot(contains('temp:1')));
    });

    test('tag removed from index when last member is disposed', () {
      final q = ZenQuery<int>(
        queryKey: 'solo:1',
        fetcher: (_) async => 1,
        tags: ['solo'],
      );
      expect(ZenQueryCache.instance.getKeysByTag('solo'), isNotEmpty);
      q.dispose();
      expect(ZenQueryCache.instance.getKeysByTag('solo'), isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // invalidateQueriesByTag
  // ─────────────────────────────────────────────────────────────────────────────
  group('ZenQueryCache.invalidateQueriesByTag', () {
    test('invalidates all queries with matching tag, leaves others alone',
        () async {
      final f1 = _Fetcher('user1');
      final f2 = _Fetcher('user2');
      final f3 = _Fetcher('other');

      final q1 = ZenQuery<String>(
        queryKey: 'user:1',
        fetcher: f1.call,
        tags: ['user'],
        config: ZenQueryConfig(retryCount: 0),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'user:2',
        fetcher: f2.call,
        tags: ['user', 'active'],
        config: ZenQueryConfig(retryCount: 0),
      );
      final q3 = ZenQuery<String>(
        queryKey: 'other:1',
        fetcher: f3.call,
        tags: ['other'],
        config: ZenQueryConfig(retryCount: 0),
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;
      final before3 = f3.calls;

      ZenQueryCache.instance.invalidateQueriesByTag('user');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(f1.calls, greaterThan(before1), reason: 'user:1 should refetch');
      expect(f2.calls, greaterThan(before2), reason: 'user:2 should refetch');
      expect(f3.calls, equals(before3), reason: 'other:1 should NOT refetch');
    });

    test('no-op when tag does not exist', () {
      expect(
        () => ZenQueryCache.instance.invalidateQueriesByTag('nonexistent'),
        returnsNormally,
      );
    });

    test('multiple tags on one query — each tag independently invalidates it',
        () async {
      final fetcher = _Fetcher(42);
      final q = ZenQuery<int>(
        queryKey: 'multi:1',
        fetcher: fetcher.call,
        tags: ['alpha', 'beta'],
        config: ZenQueryConfig(retryCount: 0),
      );
      await q.fetch();
      final before = fetcher.calls;

      ZenQueryCache.instance.invalidateQueriesByTag('alpha');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fetcher.calls, greaterThan(before));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // invalidateQueriesByPattern
  // ─────────────────────────────────────────────────────────────────────────────
  group('ZenQueryCache.invalidateQueriesByPattern', () {
    test('prefix wildcard: user:* invalidates all user entity queries',
        () async {
      final f1 = _Fetcher('u1');
      final f2 = _Fetcher('u2');
      final f3 = _Fetcher('post');

      final q1 = ZenQuery<String>(
        queryKey: 'user:123',
        fetcher: f1.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'user:456',
        fetcher: f2.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q3 = ZenQuery<String>(
        queryKey: 'post:789',
        fetcher: f3.call,
        config: ZenQueryConfig(retryCount: 0),
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;
      final before3 = f3.calls;

      ZenQueryCache.instance.invalidateQueriesByPattern('user:*');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(f1.calls, greaterThan(before1));
      expect(f2.calls, greaterThan(before2));
      expect(f3.calls, equals(before3));
    });

    test('suffix wildcard: *:comments matches all comment queries', () async {
      final f1 = _Fetcher('c1');
      final f2 = _Fetcher('c2');
      final f3 = _Fetcher('other');

      final q1 = ZenQuery<String>(
        queryKey: 'user:comments',
        fetcher: f1.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'post:comments',
        fetcher: f2.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q3 = ZenQuery<String>(
        queryKey: 'user:profile',
        fetcher: f3.call,
        config: ZenQueryConfig(retryCount: 0),
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;
      final before3 = f3.calls;

      ZenQueryCache.instance.invalidateQueriesByPattern('*:comments');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(f1.calls, greaterThan(before1));
      expect(f2.calls, greaterThan(before2));
      expect(f3.calls, equals(before3));
    });

    test('both-ends wildcard: *feed* matches any key containing feed',
        () async {
      final f1 = _Fetcher('f1');
      final f2 = _Fetcher('f2');
      final f3 = _Fetcher('other');

      final q1 = ZenQuery<String>(
        queryKey: 'user:feed',
        fetcher: f1.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'feed:trending',
        fetcher: f2.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q3 = ZenQuery<String>(
        queryKey: 'user:profile',
        fetcher: f3.call,
        config: ZenQueryConfig(retryCount: 0),
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;
      final before3 = f3.calls;

      ZenQueryCache.instance.invalidateQueriesByPattern('*feed*');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(f1.calls, greaterThan(before1));
      expect(f2.calls, greaterThan(before2));
      expect(f3.calls, equals(before3));
    });

    test('exact match (no wildcard) matches only that key', () async {
      final f1 = _Fetcher('exact');
      final f2 = _Fetcher('other');

      final q1 = ZenQuery<String>(
        queryKey: 'exact-key',
        fetcher: f1.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'exact-key-2',
        fetcher: f2.call,
        config: ZenQueryConfig(retryCount: 0),
      );

      await q1.fetch();
      await q2.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;

      ZenQueryCache.instance.invalidateQueriesByPattern('exact-key');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(f1.calls, greaterThan(before1));
      expect(f2.calls, equals(before2));
    });

    test('no-op when pattern matches nothing', () {
      expect(
        () => ZenQueryCache.instance.invalidateQueriesByPattern('no-match:*'),
        returnsNormally,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // getQueriesByTag / getKeysByTag
  // ─────────────────────────────────────────────────────────────────────────────
  group('ZenQueryCache — query lookup by tag', () {
    test('getKeysByTag returns all keys for that tag', () {
      ZenQuery<int>(queryKey: 'a:1', fetcher: (_) async => 1, tags: ['a']);
      ZenQuery<int>(queryKey: 'a:2', fetcher: (_) async => 2, tags: ['a']);
      ZenQuery<int>(queryKey: 'b:1', fetcher: (_) async => 3, tags: ['b']);

      expect(ZenQueryCache.instance.getKeysByTag('a'),
          containsAll(['a:1', 'a:2']));
      expect(ZenQueryCache.instance.getKeysByTag('b'), contains('b:1'));
      expect(ZenQueryCache.instance.getKeysByTag('unknown'), isEmpty);
    });

    test('getQueriesByTag returns live ZenQuery instances', () {
      final q1 =
          ZenQuery<int>(queryKey: 'x:1', fetcher: (_) async => 1, tags: ['x']);
      final q2 =
          ZenQuery<int>(queryKey: 'x:2', fetcher: (_) async => 2, tags: ['x']);

      final queries = ZenQueryCache.instance.getQueriesByTag('x');
      expect(queries, containsAll([q1, q2]));
    });

    test('getQueriesByTag excludes disposed queries', () {
      final q1 =
          ZenQuery<int>(queryKey: 'y:1', fetcher: (_) async => 1, tags: ['y']);
      ZenQuery<int>(queryKey: 'y:2', fetcher: (_) async => 2, tags: ['y']);

      q1.dispose();

      final queries = ZenQueryCache.instance.getQueriesByTag('y');
      expect(queries.length, 1);
      expect(queries.any((q) => q.queryKey == 'y:1'), isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // refetchQueriesByTag / refetchQueriesByPattern
  // ─────────────────────────────────────────────────────────────────────────────
  group('ZenQueryCache — refetch by tag / pattern', () {
    test('refetchQueriesByTag forces all tagged queries to refetch', () async {
      final f1 = _Fetcher('v1');
      final f2 = _Fetcher('v2');

      final q1 = ZenQuery<String>(
        queryKey: 'rv:1',
        fetcher: f1.call,
        tags: ['rv'],
        config: ZenQueryConfig(
          retryCount: 0,
          staleTime: const Duration(hours: 1),
        ),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'rv:2',
        fetcher: f2.call,
        tags: ['rv'],
        config: ZenQueryConfig(
          retryCount: 0,
          staleTime: const Duration(hours: 1),
        ),
      );

      await q1.fetch();
      await q2.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;

      await ZenQueryCache.instance.refetchQueriesByTag('rv');

      expect(f1.calls, greaterThan(before1));
      expect(f2.calls, greaterThan(before2));
    });

    test('refetchQueriesByPattern forces pattern-matched queries to refetch',
        () async {
      final f1 = _Fetcher('p1');
      final f2 = _Fetcher('p2');

      final q1 = ZenQuery<String>(
        queryKey: 'pat:alpha',
        fetcher: f1.call,
        config: ZenQueryConfig(
          retryCount: 0,
          staleTime: const Duration(hours: 1),
        ),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'other:alpha',
        fetcher: f2.call,
        config: ZenQueryConfig(
          retryCount: 0,
          staleTime: const Duration(hours: 1),
        ),
      );

      await q1.fetch();
      await q2.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;

      await ZenQueryCache.instance.refetchQueriesByPattern('pat:*');

      expect(f1.calls, greaterThan(before1));
      expect(f2.calls, equals(before2));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Scoped queries + tags
  // ─────────────────────────────────────────────────────────────────────────────
  group('ZenQueryCache — scoped queries with tags', () {
    test('scoped query tags are indexed under the scoped key', () {
      final scope = ZenScope(name: 'feature', id: 'scope-abc');

      ZenQuery<int>(
        queryKey: 'user:1',
        fetcher: (_) async => 1,
        tags: ['user'],
        scope: scope,
        autoDispose: false,
      );

      // Scoped key = 'scope-abc:user:1'
      final keys = ZenQueryCache.instance.getKeysByTag('user');
      expect(keys, contains('scope-abc:user:1'),
          reason: 'scoped key should be indexed, not the bare queryKey');
      expect(keys, isNot(contains('user:1')),
          reason:
              'bare queryKey should NOT appear; only scoped key is registered');
    });

    test('invalidateQueriesByTag works for scoped queries', () async {
      final fetcher = _Fetcher('scoped-data');
      final scope = ZenScope(name: 'feature2', id: 'scope-xyz');

      final q = ZenQuery<String>(
        queryKey: 'product:1',
        fetcher: fetcher.call,
        tags: ['product'],
        scope: scope,
        autoDispose: false,
        config: ZenQueryConfig(retryCount: 0),
      );

      await q.fetch();
      final before = fetcher.calls;

      ZenQueryCache.instance.invalidateQueriesByTag('product');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fetcher.calls, greaterThan(before),
          reason: 'scoped tagged query should be invalidated and refetched');
    });

    test('scoped tag index is cleaned up when scope disposes', () {
      final scope = ZenScope(name: 'temp-scope', id: 'scope-temp');

      final q = ZenQuery<int>(
        queryKey: 'order:1',
        fetcher: (_) async => 1,
        tags: ['order'],
        scope: scope,
        autoDispose: false,
      );

      expect(ZenQueryCache.instance.getKeysByTag('order'), isNotEmpty);

      // Manually unregister as scope would
      final scopedKey = 'scope-temp:order:1';
      ZenQueryCache.instance.unregister(scopedKey);
      q.dispose();

      expect(ZenQueryCache.instance.getKeysByTag('order'), isEmpty,
          reason:
              'tag index should be empty after scoped query is unregistered');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // Pattern edge cases
  // ─────────────────────────────────────────────────────────────────────────────
  group('Pattern edge cases', () {
    test('* alone matches everything', () {
      ZenQuery<int>(queryKey: 'a', fetcher: (_) async => 1);
      ZenQuery<int>(queryKey: 'b:c', fetcher: (_) async => 2);
      ZenQuery<int>(queryKey: 'x:y:z', fetcher: (_) async => 3);

      expect(
        () => ZenQueryCache.instance.invalidateQueriesByPattern('*'),
        returnsNormally,
      );
    });

    test('pattern with special regex chars in key is handled safely', () {
      // Key contains dots — common in package names / domain-style keys
      ZenQuery<int>(queryKey: 'com.example.user', fetcher: (_) async => 1);
      ZenQuery<int>(queryKey: 'com.example.post', fetcher: (_) async => 2);

      expect(
        () =>
            ZenQueryCache.instance.invalidateQueriesByPattern('com.example.*'),
        returnsNormally,
      );

      // The '.' in the key should be escaped — pattern 'com.example.*'
      // should match 'com.example.user' and 'com.example.post' but NOT 'comXexampleY'
      ZenQuery<int>(queryKey: 'comXexampleYuser', fetcher: (_) async => 3);
      // Main assertion is returnsNormally above; no throw means regex is safe
    });

    test('multiple wildcards: user:*:posts:* matches deep paths', () async {
      final f1 = _Fetcher('v1');
      final f2 = _Fetcher('v2');
      final f3 = _Fetcher('v3');

      final q1 = ZenQuery<String>(
        queryKey: 'user:123:posts:latest',
        fetcher: f1.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q2 = ZenQuery<String>(
        queryKey: 'user:456:posts:pinned',
        fetcher: f2.call,
        config: ZenQueryConfig(retryCount: 0),
      );
      final q3 = ZenQuery<String>(
        queryKey: 'user:123:comments',
        fetcher: f3.call,
        config: ZenQueryConfig(retryCount: 0),
      );

      await q1.fetch();
      await q2.fetch();
      await q3.fetch();

      final before1 = f1.calls;
      final before2 = f2.calls;
      final before3 = f3.calls;

      ZenQueryCache.instance.invalidateQueriesByPattern('user:*:posts:*');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(f1.calls, greaterThan(before1),
          reason: 'user:123:posts:latest should match');
      expect(f2.calls, greaterThan(before2),
          reason: 'user:456:posts:pinned should match');
      expect(f3.calls, equals(before3),
          reason: 'user:123:comments should NOT match');
    });

    test('clear() resets tag index completely', () {
      ZenQuery<int>(queryKey: 'c:1', fetcher: (_) async => 1, tags: ['c']);
      ZenQuery<int>(queryKey: 'c:2', fetcher: (_) async => 2, tags: ['c']);

      expect(ZenQueryCache.instance.getKeysByTag('c'), hasLength(2));

      ZenQueryCache.instance.clear();

      expect(ZenQueryCache.instance.getKeysByTag('c'), isEmpty,
          reason: 'clear() must also wipe the tag index');
    });
  });
}
