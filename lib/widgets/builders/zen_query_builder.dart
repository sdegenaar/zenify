import 'package:flutter/material.dart';
import '../../core/zen_logger.dart';
import '../../query/logic/zen_query.dart';
import 'package:zenify/query/core/zen_query_enums.dart';

/// A widget that builds itself based on the state of a [ZenQuery].
///
/// It handles the main states:
/// - [loading]: Query is fetching and no data exists yet.
/// - [error]: Query failed.
/// - [builder]: Query has data (or placeholder data).
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

  /// If true, keeps showing the data from the previous query instance
  /// (if available) while the new query is loading.
  ///
  /// Useful for pagination to prevent "flash of loading" when key changes.
  final bool keepPreviousData;

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
    this.keepPreviousData = false,
    this.wrapper,
  });

  @override
  State<ZenQueryBuilder<T>> createState() => _ZenQueryBuilderState<T>();
}

class _ZenQueryBuilderState<T> extends State<ZenQueryBuilder<T>> {
  T? _previousData;
  bool _showingPreviousData = false;

  @override
  void initState() {
    super.initState();

    // Store initial data for previous data logic if we have it
    if (widget.query.hasData) {
      _previousData = widget.query.data.value;
    }

    // Auto-fetch on mount if enabled
    if (widget.autoFetch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.query.isDisposed && widget.query.enabled.value) {
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
    _attachListeners(widget.query);
  }

  void _attachListeners(ZenQuery<T> query) {
    query.status.addListener(_onQueryStateChange);
    query.data.addListener(_onQueryStateChange);
    query.error.addListener(_onQueryStateChange);
  }

  void _detachListeners(ZenQuery<T> query) {
    query.status.removeListener(_onQueryStateChange);
    query.data.removeListener(_onQueryStateChange);
    query.error.removeListener(_onQueryStateChange);
  }

  @override
  void didUpdateWidget(ZenQueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Query instance changed - handle transition
    if (oldWidget.query != widget.query) {
      // Update listeners
      _detachListeners(oldWidget.query);
      _attachListeners(widget.query);

      // Transition Strategy: Determine what data to show during the switch
      if (widget.query.hasData) {
        // New query already has data - use it immediately
        _previousData = widget.query.data.value;
        _showingPreviousData = false;
      } else if (widget.keepPreviousData && oldWidget.query.hasData) {
        // New query has no data - keep showing old data if keepPreviousData is enabled
        _previousData = oldWidget.query.data.value;
        _showingPreviousData = true;
      } else {
        // No previous data strategy - reset
        _showingPreviousData = false;
        if (!widget.keepPreviousData) {
          _previousData = null;
        }
      }

      // Auto-fetch new query if needed
      if (widget.autoFetch &&
          widget.query.enabled.value &&
          !widget.query.isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !widget.query.isDisposed) {
            widget.query.fetch().then(
              (_) {},
              onError: (error, stackTrace) {
                ZenLogger.logError(
                  'ZenQueryBuilder auto-fetch failed for updated query: ${widget.query.queryKey}',
                  error,
                  stackTrace,
                );
              },
            );
          }
        });
      }
    }
    // Same query instance - just update buffer if data refreshed
    else if (widget.query.hasData) {
      _previousData = widget.query.data.value;
      _showingPreviousData = false;
    }
  }

  @override
  void dispose() {
    _detachListeners(widget.query);
    super.dispose();
  }

  void _onQueryStateChange() {
    if (mounted) {
      // Update buffer and state when query data changes
      if (widget.query.hasData) {
        _previousData = widget.query.data.value;
        // Stop showing previous data once new data arrives
        if (_showingPreviousData) {
          _showingPreviousData = false;
        }
      }

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

    // 1. Show Current Data (Priority)
    // If we have valid data, show it.
    // Exception: If user explicitly disabled showStaleData and we are refetching.
    bool shouldShowCurrentData = data != null;
    if (!widget.showStaleData && isRefetching) {
      shouldShowCurrentData = false;
    }

    if (shouldShowCurrentData) {
      child = widget.builder(context, data as T);
    }
    // 2. Show Previous Data (KeepPreviousData)
    // If current data is missing, but we have previous data and flag is on.
    else if (_showingPreviousData && _previousData != null) {
      child = widget.builder(context, _previousData as T);
    }
    // 3. Loading
    else if (status == ZenQueryStatus.loading) {
      child = widget.loading?.call() ??
          const Center(child: CircularProgressIndicator());
    }
    // 4. Error
    else if (status == ZenQueryStatus.error && error != null) {
      child = widget.error?.call(error, _retry) ?? _buildDefaultError(error);
    }
    // 5. Idle
    else {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
            ),
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
