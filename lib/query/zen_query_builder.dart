import 'package:flutter/material.dart';
import '../core/zen_logger.dart';
import 'zen_query.dart';
import 'zen_query_config.dart';

/// Widget that builds UI based on ZenQuery state
///
/// Automatically fetches data on mount and rebuilds on state changes.
///
/// Example:
/// ```dart
/// ZenQueryBuilder<User>(
///   query: userQuery,
///   builder: (context, data) => Text(data.name),
///   loading: () => CircularProgressIndicator(),
///   error: (error, retry) => ErrorView(error, retry),
/// );
/// ```
class ZenQueryBuilder<T> extends StatefulWidget {
  /// The query to observe
  final ZenQuery<T> query;

  /// Builder for success state with data
  final Widget Function(BuildContext context, T data) builder;

  /// Builder for loading state
  final Widget Function()? loading;

  /// Builder for error state with retry function
  final Widget Function(Object error, VoidCallback retry)? error;

  /// Builder for idle state (before first fetch)
  final Widget Function()? idle;

  /// Whether to automatically fetch on mount
  final bool autoFetch;

  /// Whether to show stale data while refetching
  final bool showStaleData;

  /// Custom wrapper for all states
  final Widget Function(BuildContext context, Widget child)? wrapper;

  const ZenQueryBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.loading,
    this.error,
    this.idle,
    this.autoFetch = true,
    this.showStaleData = true,
    this.wrapper,
  });

  @override
  State<ZenQueryBuilder<T>> createState() => _ZenQueryBuilderState<T>();
}

class _ZenQueryBuilderState<T> extends State<ZenQueryBuilder<T>> {
  @override
  void initState() {
    super.initState();

    // Auto-fetch on mount if enabled
    if (widget.autoFetch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.query.isDisposed) {
          widget.query.fetch().then(
            (_) {
              // Success - no action needed
            },
            onError: (error, stackTrace) {
              ZenLogger.logError(
                'ZenQueryBuilder auto-fetch failed for query: ${widget.query.queryKey}',
                error,
                stackTrace,
              );
              // Error is handled by the query's error state
            },
          );
        }
      });
    }

    // Listen to query state changes
    widget.query.status.addListener(_onQueryStateChange);
    widget.query.data.addListener(_onQueryStateChange);
    widget.query.error.addListener(_onQueryStateChange);
  }

  @override
  void didUpdateWidget(ZenQueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update listeners if query changed
    if (oldWidget.query != widget.query) {
      oldWidget.query.status.removeListener(_onQueryStateChange);
      oldWidget.query.data.removeListener(_onQueryStateChange);
      oldWidget.query.error.removeListener(_onQueryStateChange);

      widget.query.status.addListener(_onQueryStateChange);
      widget.query.data.addListener(_onQueryStateChange);
      widget.query.error.addListener(_onQueryStateChange);

      // Auto-fetch for new query
      if (widget.autoFetch) {
        widget.query.fetch().then(
          (_) {
            // Success - no action needed
          },
          onError: (error, stackTrace) {
            ZenLogger.logError(
              'ZenQueryBuilder auto-fetch failed for updated query: ${widget.query.queryKey}',
              error,
              stackTrace,
            );
            // Error is handled by the query's error state
          },
        );
      }
    }
  }

  @override
  void dispose() {
    widget.query.status.removeListener(_onQueryStateChange);
    widget.query.data.removeListener(_onQueryStateChange);
    widget.query.error.removeListener(_onQueryStateChange);
    super.dispose();
  }

  void _onQueryStateChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _retry() {
    widget.query.refetch().then(
      (_) {
        // Success - no action needed
      },
      onError: (error, stackTrace) {
        ZenLogger.logError(
          'ZenQueryBuilder retry failed for query: ${widget.query.queryKey}',
          error,
          stackTrace,
        );
        // Error is handled by the query's error state
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    final status = widget.query.status.value;
    final data = widget.query.data.value;
    final error = widget.query.error.value;
    final isRefetching = widget.query.isRefetching;

    // Show stale data while refetching (if enabled)
    if (widget.showStaleData && isRefetching && data != null) {
      child = widget.builder(context, data);
    }
    // Handle states based on priority: loading > error > success > idle
    else if (status == ZenQueryStatus.loading && data == null) {
      child = widget.loading?.call() ??
          const Center(child: CircularProgressIndicator());
    } else if (status == ZenQueryStatus.error && error != null) {
      child = widget.error?.call(error, _retry) ?? _buildDefaultError(error);
    } else if (status == ZenQueryStatus.success && data != null) {
      child = widget.builder(context, data);
    } else {
      // Idle state
      child = widget.idle?.call() ?? const SizedBox.shrink();
    }

    // Apply wrapper if provided
    if (widget.wrapper != null) {
      return widget.wrapper!(context, child);
    }

    return child;
  }

  Widget _buildDefaultError(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE57373),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Query Error',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _retry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Color(0xFFFFFFFF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
