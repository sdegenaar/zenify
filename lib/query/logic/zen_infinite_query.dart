import 'dart:async';
import 'package:zenify/query/core/zen_cancel_token.dart';
import '../../reactive/core/rx_value.dart';
import 'zen_query.dart';
import '../core/zen_query_cache.dart';
import '../core/zen_query_enums.dart';

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

  /// Function to determine the previous page param based on the first page.
  /// Return null if there are no previous pages.
  final dynamic Function(T firstPage, List<T> allPages)? getPreviousPageParam;

  /// The actual fetcher that takes a page param and a cancel token.
  final Future<T> Function(dynamic pageParam, ZenCancelToken cancelToken)
      infiniteFetcher;

  /// The initial page parameter to use for the first page.
  final dynamic initialPageParam;

  // Tracks if we are currently fetching the next page
  final RxBool isFetchingNextPage = RxBool(false);

  // Tracks if we are currently fetching the previous page
  final RxBool isFetchingPreviousPage = RxBool(false);

  // Tracks if there is a next page available
  final RxBool hasNextPage = RxBool(true);

  // Tracks if there is a previous page available
  final RxBool hasPreviousPage = RxBool(false);

  // Stores the next page param to be used
  dynamic _nextPageParam;

  // Stores the previous page param to be used
  dynamic _previousPageParam;

  /// Token for the current "next page" fetch to allow specific cancellation
  ZenCancelToken? _nextPageCancelToken;

  /// Token for the current "previous page" fetch
  ZenCancelToken? _previousPageCancelToken;

  ZenInfiniteQuery({
    required super.queryKey,
    required this.infiniteFetcher,
    required this.getNextPageParam,
    this.getPreviousPageParam,
    this.initialPageParam,
    super.config,
    super.initialData,
    super.scope,
    super.autoDispose,
  })  : _nextPageParam = initialPageParam,
        _previousPageParam =
            initialPageParam, // Initially same, logic corrects it
        super(
          // The main fetcher (for initial load/refetch)
          fetcher: (token) async {
            // Pass the token to the infinite fetcher
            final firstPage = await infiniteFetcher(initialPageParam, token);
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

    // Create token for this specific operation
    _nextPageCancelToken?.cancel('New next page fetch started');
    final token = ZenCancelToken('Fetching next page');
    _nextPageCancelToken = token;

    try {
      // 1. Fetch the new page using the stored param
      final newPage = await infiniteFetcher(_nextPageParam, token);

      if (isDisposed || token.isCancelled) return;

      // 2. Append to existing pages
      final currentPages = data.value ?? [];
      final allPages = [...currentPages, newPage];

      // 3. Update the reactive data
      _updateDataAndCache(allPages);

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
      _handleFetchError(e, token);
    } finally {
      if (!isDisposed) {
        isFetchingNextPage.value = false;
        if (_nextPageCancelToken == token) {
          _nextPageCancelToken = null;
        }
        update();
      }
    }
  }

  /// Fetch the previous page of data.
  Future<void> fetchPreviousPage() async {
    if (isFetchingPreviousPage.value || !hasPreviousPage.value || isDisposed) {
      return;
    }

    isFetchingPreviousPage.value = true;
    update();

    _previousPageCancelToken?.cancel('New previous page fetch started');
    final token = ZenCancelToken('Fetching previous page');
    _previousPageCancelToken = token;

    try {
      final newPage = await infiniteFetcher(_previousPageParam, token);

      if (isDisposed || token.isCancelled) return;

      final currentPages = data.value ?? [];
      final allPages = [newPage, ...currentPages];

      _updateDataAndCache(allPages);

      // Calculate params again
      _updateParams(allPages);

      error.value = null;
    } catch (e) {
      _handleFetchError(e, token);
    } finally {
      if (!isDisposed) {
        isFetchingPreviousPage.value = false;
        if (_previousPageCancelToken == token) {
          _previousPageCancelToken = null;
        }
        update();
      }
    }
  }

  void _updateDataAndCache(List<T> allPages) {
    // We use setData to ensure timestamps are updated in the cache
    data.value = allPages;
    // Manually update cache entry since we modified data outside standard fetch()
    ZenQueryCache.instance.updateCache(queryKey, allPages, DateTime.now());
  }

  void _handleFetchError(Object e, ZenCancelToken token) {
    if (!isDisposed && !token.isCancelled) {
      // We generally set the error state but keep the old data
      error.value = e;
      // Note: We do NOT set status to ZenQueryStatus.error because
      // we still have valid pages displayed.
    }
  }

  @override
  Future<List<T>> fetch({bool force = false}) async {
    // When performing a full refresh (force=true), we reset the pagination state
    if (force) {
      _nextPageParam = initialPageParam;
      _previousPageParam = null; // Reset previous
      hasNextPage.value = true;
      hasPreviousPage.value = false;
      isFetchingNextPage.value = false;
      isFetchingPreviousPage.value = false;

      // Cancel any ongoing "next/prev page" fetch
      _nextPageCancelToken?.cancel('Full refresh triggered');
      _nextPageCancelToken = null;
      _previousPageCancelToken?.cancel('Full refresh triggered');
      _previousPageCancelToken = null;
    }

    final result = await super.fetch(force: force);

    // After the initial page loads, calculate cursors
    if (!isDisposed && result.isNotEmpty) {
      _updateParams(result);
    }

    return result;
  }

  void _updateParams(List<T> pages) {
    // Update next param
    final nextParam = getNextPageParam(pages.last, pages);
    _nextPageParam = nextParam;
    hasNextPage.value = nextParam != null;

    // Update previous param
    if (getPreviousPageParam != null) {
      final prevParam = getPreviousPageParam!(pages.first, pages);
      _previousPageParam = prevParam;
      hasPreviousPage.value = prevParam != null;
    }
  }

  @override
  void onClose() {
    _nextPageCancelToken?.cancel('Query disposed');
    _previousPageCancelToken?.cancel('Query disposed');
    isFetchingNextPage.dispose();
    isFetchingPreviousPage.dispose();
    hasNextPage.dispose();
    hasPreviousPage.dispose();
    super.onClose();
  }
}
