import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

class User {
  final int id;
  final String name;
  final int age;

  User(this.id, this.name, this.age);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          age == other.age;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ age.hashCode;
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Zen.init();
    Zen.testMode().clearQueryCache();
  });

  tearDown(() {
    Zen.reset();
  });

  group('ZenQuery.select()', () {
    test('should derive data from parent query', () async {
      final userQuery = ZenQuery<User>(
        queryKey: 'user:1',
        fetcher: (_) async => User(1, 'Alice', 25),
      );

      final nameQuery = userQuery.select((user) => user.name);

      // Initial state should be null if parent is null
      expect(nameQuery.data.value, null);

      // Fetch parent
      await userQuery.fetch();

      // Derived query should update
      expect(nameQuery.data.value, 'Alice');
      expect(nameQuery.status.value, ZenQueryStatus.success);
    });

    test('should only update when selected value changes', () async {
      final userQuery = ZenQuery<User>(
        queryKey: 'user:2',
        fetcher: (_) async => User(2, 'Bob', 30),
      );

      final ageQuery = userQuery.select((user) => user.age);
      int updateCount = 0;
      ageQuery.data.addListener(() {
        updateCount++;
      });

      // 1. Initial fetch
      await userQuery.fetch();
      expect(ageQuery.data.value, 30);
      expect(updateCount, 1);

      // 2. Update parent with SAME age but DIFFERENT name
      // (Simulate optimistic update or refetch)
      userQuery.setData(User(2, 'Bobby', 30));

      // Parent changed
      expect(userQuery.data.value!.name, 'Bobby');

      // Derived query should NOT have triggered listener again
      expect(ageQuery.data.value, 30);
      expect(updateCount, 1); // Still 1

      // 3. Update parent with NEW age
      userQuery.setData(User(2, 'Bobby', 31));

      // Derived query SHOULD trigger
      expect(ageQuery.data.value, 31);
      expect(updateCount, 2);
    });

    test('derived query should sync loading and error states', () async {
      final userQuery = ZenQuery<User>(
        queryKey: 'user:3',
        fetcher: (_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Network Error');
        },
        config: const ZenQueryConfig(retryCount: 0),
      );

      final nameQuery = userQuery.select((user) => user.name);

      // Start fetch
      final future = userQuery.fetch();

      // Loading state should sync
      // Note: isLoading might need a microtask to propogate if using listeners
      await Future.delayed(Duration.zero);
      expect(nameQuery.isLoading.value, true);
      expect(nameQuery.status.value, ZenQueryStatus.loading);

      // Wait for error
      try {
        await future;
      } catch (_) {}

      expect(nameQuery.isLoading.value, false);
      expect(nameQuery.status.value, ZenQueryStatus.error);
      expect(nameQuery.error.value, isA<Exception>());
    });

    test('derived query should handle selector errors gracefully', () async {
      final userQuery = ZenQuery<User>(
        queryKey: 'user:4',
        fetcher: (_) async => User(4, 'Dave', 40),
      );

      // Selector that throws
      final faultyQuery = userQuery.select((user) {
        throw Exception('Selector Logic Error');
      });

      await userQuery.fetch();

      expect(faultyQuery.status.value, ZenQueryStatus.error);
      expect(
          faultyQuery.error.value.toString(), contains('Selector Logic Error'));
    });

    test('lifecycle: derived query disposal cleans up listeners', () async {
      final userQuery = ZenQuery<User>(
        queryKey: 'user:5',
        fetcher: (_) async => User(5, 'Eve', 50),
      );

      final nameQuery = userQuery.select((user) => user.name);

      await userQuery.fetch();
      expect(nameQuery.data.value, 'Eve');

      // Dispose derived query
      nameQuery.dispose();

      // Update parent
      userQuery.setData(User(5, 'Evelyn', 50));

      // Derived query should NOT update (it's disposed)
      expect(nameQuery.isDisposed, true);
    });

    test('scope integration: derived query is not cached globally', () async {
      final userQuery = ZenQuery<User>(
        queryKey: 'user:6',
        fetcher: (_) async => User(6, 'Frank', 60),
      );

      // Derived query
      final nameQuery = userQuery.select((user) => user.name);

      // Use the variable to silence warning and verify creation
      expect(nameQuery, isNotNull);

      // Parent should be in cache
      expect(ZenQueryCache.instance.getQuery('user:6'), isNotNull);

      // Derived query should NOT be in cache (it uses internal key)
      // We can check cache stats
      final stats = ZenQueryCache.instance.getStats();
      // Only 1 query (the parent) should be registered
      expect(stats['total_queries'], 1);
    });

    test('scope integration: derived query respects parent scope', () async {
      final scope = ZenScope(name: 'ModuleScope');

      final userQuery = ZenQuery<User>(
        queryKey: 'user:scoped',
        fetcher: (_) async => User(7, 'Grace', 70),
        scope: scope,
      );

      final nameQuery = userQuery.select((user) => user.name);

      // Derived query should inherit scope reference
      expect(nameQuery.scope, scope);

      await userQuery.fetch();
      expect(nameQuery.data.value, 'Grace');

      // Dispose scope
      scope.dispose();

      // Parent should be disposed
      expect(userQuery.isDisposed, true);

      // Derived query relies on parent, so it effectively stops working,
      // but we should manually dispose it if it was created in a controller.
      nameQuery.dispose();
    });
  });
}
