import 'query_key.dart';
import '../logic/zen_query.dart';

/// Filter type for querying the cache by query lifecycle and network state.
enum QueryTypeFilter {
  /// All queries, regardless of state.
  all,

  /// Active queries (non-disposed and enabled).
  active,

  /// Inactive queries (disposed or disabled).
  inactive,

  /// Queries whose data is currently stale or failed with an error.
  stale,

  /// Queries currently executing an active network fetch.
  fetching,
}

/// A flexible filter used for batch query cache operations.
///
/// Supports filtering by:
/// - [queryKey]: String, List, or Object key matching (exact, prefix, or glob `*` wildcards).
/// - [exact]: When true, [queryKey] matches strictly. When false (default), supports wildcards or prefix matching.
/// - [tags]: Matches queries carrying any (or all) of the specified tags.
/// - [matchAllTags]: When true, a query must contain ALL tags in [tags]. When false (default), ANY tag matches.
/// - [type]: Filter by [QueryTypeFilter] (`all`, `active`, `inactive`, `stale`, `fetching`).
/// - [isFetching]: Optional boolean filter for active fetch status.
/// - [isStale]: Optional boolean filter for staleness.
/// - [predicate]: Custom boolean filter function `bool Function(ZenQuery query)`.
///
/// **Examples:**
/// ```dart
/// // All queries matching a glob pattern
/// final filter = ZenQueryFilter(queryKey: 'users:*');
///
/// // All queries tagged 'feed' that are currently active
/// final filter = ZenQueryFilter(
///   tags: ['feed'],
///   type: QueryTypeFilter.active,
/// );
///
/// // Custom predicate
/// final filter = ZenQueryFilter(
///   predicate: (query) => query.queryKey.startsWith('profile:'),
/// );
/// ```
class ZenQueryFilter {
  /// Query key, prefix, or glob pattern to match against.
  final Object? queryKey;

  /// Whether the query key must match exactly.
  ///
  /// Defaults to `false`, which enables glob wildcard (`*`) and prefix matching.
  final bool exact;

  /// List of tags to match against.
  final List<String>? tags;

  /// Whether all tags in [tags] must be present on the query (`true`),
  /// or if having at least one matching tag is sufficient (`false`, default).
  final bool matchAllTags;

  /// Filter by query state type (all, active, inactive, stale, fetching).
  final QueryTypeFilter type;

  /// Explicit filter for fetching state.
  ///
  /// If `true`, only queries currently fetching will match.
  /// If `false`, only queries not fetching will match.
  /// If `null` (default), fetching state is not explicitly checked (unless [type] is `fetching`).
  final bool? isFetching;

  /// Explicit filter for staleness.
  ///
  /// If `true`, only stale queries will match.
  /// If `false`, only fresh queries will match.
  /// If `null` (default), staleness is not explicitly checked (unless [type] is `stale`).
  final bool? isStale;

  /// Custom predicate function for arbitrary matching logic.
  final bool Function(ZenQuery query)? predicate;

  const ZenQueryFilter({
    this.queryKey,
    this.exact = false,
    this.tags,
    this.matchAllTags = false,
    this.type = QueryTypeFilter.all,
    this.isFetching,
    this.isStale,
    this.predicate,
  });

  /// Check whether an active [ZenQuery] instance matches all criteria of this filter.
  bool matches(ZenQuery query) {
    // 1. Check query key
    if (queryKey != null) {
      final normalizedFilterKey = QueryKey.normalize(queryKey!);
      if (!_matchesKey(query.queryKey, normalizedFilterKey, exact)) {
        return false;
      }
    }

    // 2. Check tags
    if (tags != null && tags!.isNotEmpty) {
      if (!_matchesTags(query.tags, tags!, matchAllTags)) {
        return false;
      }
    }

    // 3. Check QueryTypeFilter
    switch (type) {
      case QueryTypeFilter.all:
        break;
      case QueryTypeFilter.active:
        if (query.isDisposed || !query.enabled.value) return false;
        break;
      case QueryTypeFilter.inactive:
        if (!query.isDisposed && query.enabled.value) return false;
        break;
      case QueryTypeFilter.stale:
        if (!query.isStale && !query.hasError) return false;
        break;
      case QueryTypeFilter.fetching:
        if (!query.isFetching) return false;
        break;
    }

    // 4. Check explicit isFetching
    if (isFetching != null && query.isFetching != isFetching) {
      return false;
    }

    // 5. Check explicit isStale
    if (isStale != null && query.isStale != isStale) {
      return false;
    }

    // 6. Check custom predicate
    if (predicate != null && !predicate!(query)) {
      return false;
    }

    return true;
  }

  /// Check whether a query key and tag set match the key and tag criteria of this filter.
  ///
  /// Useful for matching cached entries that may not have an active [ZenQuery] instance mounted.
  bool matchesKeyAndTags(
    String key, {
    List<String>? queryTags,
    bool queryIsStale = false,
    bool queryIsFetching = false,
  }) {
    // 1. Check query key
    if (queryKey != null) {
      final normalizedFilterKey = QueryKey.normalize(queryKey!);
      if (!_matchesKey(key, normalizedFilterKey, exact)) {
        return false;
      }
    }

    // 2. Check tags
    if (tags != null && tags!.isNotEmpty) {
      final actualTags = queryTags ?? const [];
      if (!_matchesTags(actualTags, tags!, matchAllTags)) {
        return false;
      }
    }

    // 3. Check type if applicable
    if (type == QueryTypeFilter.stale && !queryIsStale) {
      return false;
    }
    if (type == QueryTypeFilter.fetching && !queryIsFetching) {
      return false;
    }

    // 4. Check explicit isFetching
    if (isFetching != null && queryIsFetching != isFetching) {
      return false;
    }

    // 5. Check explicit isStale
    if (isStale != null && queryIsStale != isStale) {
      return false;
    }

    return true;
  }

  /// Helper to test key matching with exact, prefix, or glob pattern support.
  static bool _matchesKey(String actualKey, String filterKey, bool exact) {
    if (exact) {
      return actualKey == filterKey;
    }

    // Glob pattern with wildcard (*)
    if (filterKey.contains('*')) {
      final parts = filterKey.split('*').map(RegExp.escape).join('.*');
      final regex = RegExp('^$parts' r'$');
      return regex.hasMatch(actualKey);
    }

    // Exact or prefix match (e.g. 'users' matches 'users', 'users:123', 'users/456')
    if (actualKey == filterKey) return true;
    if (actualKey.startsWith('$filterKey:') ||
        actualKey.startsWith('$filterKey/') ||
        actualKey.startsWith('$filterKey.')) {
      return true;
    }

    return false;
  }

  /// Helper to test tag matching.
  static bool _matchesTags(
    List<String> actualTags,
    List<String> filterTags,
    bool matchAll,
  ) {
    if (actualTags.isEmpty) return false;

    if (matchAll) {
      return filterTags.every((t) => actualTags.contains(t));
    } else {
      return filterTags.any((t) => actualTags.contains(t));
    }
  }
}
