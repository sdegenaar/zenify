import 'dart:async';
import '../reactive/reactive.dart';
import 'zen_query.dart';
import 'zen_query_config.dart';
import 'zen_query_cache.dart';

/// A specialized query for infinite scrolling / pagination.
///
/// It manages a list of pages [List<T>] and handles fetching the next page
/// based on the previous page's data.
///
/// [T] is the type of data in a single page (e.g. a Page object or a List of items).
class ZenInfiniteQuery<T> extends ZenQuery<List<T>> {
  /// Function to determine the next page param based on the last page.
  /// Return null if there are no more pages.
  final dynamic Function(T lastPage, List<T> allPages) getNextPageParam;

  /// The actual fetcher that takes a page param.
  final Future<T> Function(dynamic pageParam) infiniteFetcher;

  /// The initial page parameter to use for the first page.
  final dynamic initialPageParam;

  // Tracks if we are currently fetching the next page
  final RxBool isFetchingNextPage = RxBool(false);

  // Tracks if there is a next page available
  final RxBool hasNextPage = RxBool(true);

  // Stores the next page param to be used
  dynamic _nextPageParam;

  ZenInfiniteQuery({
    required super.queryKey,
    required this.infiniteFetcher,
    required this.getNextPageParam,
    this.initialPageParam,
    super.config,
    super.initialData,
    super.scope,
    super.autoDispose,
  })  : _nextPageParam = initialPageParam,
        super(
          fetcher: () async {
            final firstPage = await infiniteFetcher(initialPageParam);
            return [firstPage];
          },
        );

  /// Fetch the next page of data.
  ///
  /// If already fetching or no next page exists, this does nothing.
  Future<void> fetchNextPage() async {
    if (isFetchingNextPage.value || !hasNextPage.value || isDisposed) {
      return;
    }

    isFetchingNextPage.value = true;
    update(); // Update UI to show loading footer

    try {
      // 1. Fetch the new page using the stored param
      final newPage = await infiniteFetcher(_nextPageParam);

      if (isDisposed) return;

      // 2. Append to existing pages
      final currentPages = data.value ?? [];
      final allPages = [...currentPages, newPage];

      // 3. Update the reactive data
      // We use setData to ensure timestamps are updated in the cache
      data.value = allPages;

      // Manually update cache entry since we modified data outside standard fetch()
      ZenQueryCache.instance.updateCache(queryKey, allPages, DateTime.now());

      // 4. Calculate the cursor for the NEXT fetch
      final nextParam = getNextPageParam(newPage, allPages);
      _nextPageParam = nextParam;
      hasNextPage.value = nextParam != null;

      // 5. Ensure status is success
      if (status.value != ZenQueryStatus.success) {
        status.value = ZenQueryStatus.success;
      }

      // Clear any previous errors since this succeeded
      error.value = null;
    } catch (e) {
      if (!isDisposed) {
        // We generally set the error state but keep the old data
        error.value = e;
        // Note: We do NOT set status to ZenQueryStatus.error because
        // we still have valid pages displayed.
        // The UI should check 'error' to show a toast/snackbar.
      }
    } finally {
      if (!isDisposed) {
        isFetchingNextPage.value = false;
        update();
      }
    }
  }

  @override
  Future<List<T>> fetch({bool force = false}) async {
    // When performing a full refresh (force=true), we reset the pagination state
    if (force) {
      _nextPageParam = initialPageParam;
      hasNextPage.value = true;
      isFetchingNextPage.value = false;
    }

    final result = await super.fetch(force: force);

    // After the initial page loads, calculate if a second page exists
    if (!isDisposed && result.isNotEmpty) {
      final nextParam = getNextPageParam(result.last, result);
      _nextPageParam = nextParam;
      hasNextPage.value = nextParam != null;
    }

    return result;
  }

  @override
  void onClose() {
    isFetchingNextPage.dispose();
    hasNextPage.dispose();
    super.onClose();
  }
}
