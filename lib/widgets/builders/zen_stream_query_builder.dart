import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

/// A widget that builds itself based on the state of a [ZenStreamQuery].
///
/// It handles the 3 main states:
/// - [loading]: Stream is connecting and no data exists yet.
/// - [error]: Stream emitted an error.
/// - [builder]: Stream has emitted data (or has initial data).
class ZenStreamQueryBuilder<T> extends StatefulWidget {
  final ZenStreamQuery<T> query;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function()? loading;
  final Widget Function(Object error)? error;
  final Widget Function()? empty; // Optional: for empty lists/iterables

  /// If true, keeps showing the data from the previous query instance
  /// (if available) while the new query is connecting.
  final bool keepPreviousData;

  const ZenStreamQueryBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.loading,
    this.error,
    this.empty,
    this.keepPreviousData = false,
  });

  @override
  State<ZenStreamQueryBuilder<T>> createState() =>
      _ZenStreamQueryBuilderState<T>();
}

class _ZenStreamQueryBuilderState<T> extends State<ZenStreamQueryBuilder<T>> {
  T? _previousData;
  bool _showingPreviousData = false;

  @override
  void initState() {
    super.initState();
    // Store initial data if available
    if (widget.query.hasData) {
      _previousData = widget.query.data.value;
    }
    _attachListeners(widget.query);
  }

  @override
  void didUpdateWidget(ZenStreamQueryBuilder<T> oldWidget) {
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

  void _attachListeners(ZenStreamQuery<T> query) {
    query.status.addListener(_onStateChange);
    query.data.addListener(_onStateChange);
    query.error.addListener(_onStateChange);
  }

  void _detachListeners(ZenStreamQuery<T> query) {
    query.status.removeListener(_onStateChange);
    query.data.removeListener(_onStateChange);
    query.error.removeListener(_onStateChange);
  }

  void _onStateChange() {
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

  @override
  Widget build(BuildContext context) {
    final status = widget.query.status.value;
    final data = widget.query.data.value;
    final error = widget.query.error.value;

    // 1. Show Current Data
    if (data != null) {
      return _buildDataState(context, data);
    }

    // 2. Show Previous Data (KeepPreviousData)
    if (_showingPreviousData && _previousData != null) {
      return _buildDataState(context, _previousData as T);
    }

    // 3. Error State
    if (status == ZenQueryStatus.error && error != null) {
      if (widget.error != null) {
        return widget.error!(error);
      }
      return Center(
        child: Text(
          'Stream Error: $error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    // 4. Loading / Idle State
    // (Streams often start as 'loading' or 'idle' before first event)
    if (widget.loading != null) {
      return widget.loading!();
    }

    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildDataState(BuildContext context, T data) {
    // Handle Empty State for Iterables (Lists, Sets, etc.)
    if (widget.empty != null && data is Iterable && data.isEmpty) {
      return widget.empty!();
    }
    return widget.builder(context, data);
  }
}
