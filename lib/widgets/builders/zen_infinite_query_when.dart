import 'package:flutter/widgets.dart';
import '../../query/logic/zen_infinite_query.dart';
import 'zen_query_builder.dart';

/// Convenience extension on [ZenInfiniteQuery] for declarative UI building.
///
/// Provides infinite-scroll-aware builders that expose the paging controls
/// as part of the data callback, making it easy to drive a [ListView] with
/// a "Load More" footer.
extension ZenInfiniteQueryWhenExtension<T> on ZenInfiniteQuery<T> {
  /// Builds UI declaratively based on the infinite query state.
  ///
  /// The [data] builder receives:
  /// - `pages` — all loaded pages as a flat `List<T>`
  /// - `hasNextPage` — whether more pages are available
  /// - `fetchNextPage` — call to load the next page
  ///
  /// Example:
  /// ```dart
  /// postsQuery.when(
  ///   data: (pages, hasNextPage, fetchNextPage) => ListView.builder(
  ///     itemCount: pages.length + (hasNextPage ? 1 : 0),
  ///     itemBuilder: (context, index) {
  ///       if (index == pages.length) {
  ///         fetchNextPage();
  ///         return const CircularProgressIndicator();
  ///       }
  ///       return PostTile(pages[index]);
  ///     },
  ///   ),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, retry) => ErrorView(e, onRetry: retry),
  /// )
  /// ```
  Widget when({
    required Widget Function(
      List<T> pages,
      bool hasNextPage,
      VoidCallback fetchNextPage,
    ) data,
    Widget Function()? loading,
    Widget Function(Object error, VoidCallback retry)? error,
    Widget Function()? idle,
    bool autoFetch = true,
    bool showStaleData = true,
  }) {
    return ZenQueryBuilder<List<T>>(
      query: this,
      builder: (context, pages) => data(
        pages,
        hasNextPage.value,
        () => fetchNextPage(),
      ),
      loading: loading,
      error: error,
      idle: idle,
      autoFetch: autoFetch,
      showStaleData: showStaleData,
    );
  }
}
