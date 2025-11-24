import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  setUp(() {
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQueryCache', () {
    test('should register and retrieve queries', () {
      final query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: (_) async => 'data',
      );

      final retrieved = ZenQueryCache.instance.getQuery<String>('test');
      expect(retrieved, query);
    });

    test('should cache query results', () async {
      final query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: (_) async => 'cached-data',
      );

      await query.fetch();

      final cached = ZenQueryCache.instance.getCachedData<String>('test');
      expect(cached, 'cached-data');
    });

    test('should invalidate cached queries', () async {
      final query = ZenQuery<String>(
        queryKey: 'test',
        fetcher: (_) async => 'data',
        config: const ZenQueryConfig(staleTime: Duration(hours: 1)),
      );

      await query.fetch();
      expect(query.isStale, false);

      ZenQueryCache.instance.invalidateQuery('test');
      expect(query.isStale, true);
    });

    test('should clear all queries and cache', () {
      final query1 = ZenQuery<String>(
        queryKey: 'test1',
        fetcher: (_) async => 'data1',
      );

      final query2 = ZenQuery<String>(
        queryKey: 'test2',
        fetcher: (_) async => 'data2',
      );

      expect(ZenQueryCache.instance.queries.length, 2);

      ZenQueryCache.instance.clear();

      expect(ZenQueryCache.instance.queries.length, 0);

      // Cleanup
      query1.dispose();
      query2.dispose();
    });
  });
}
