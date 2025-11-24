import 'package:flutter/material.dart';
import '../components/rx_widgets.dart';
import '../../query/logic/zen_stream_query.dart';

/// A widget that builds itself based on the state of a [ZenStreamQuery].
///
/// It handles the 3 main states:
/// - [loading]: Stream is connecting and no data exists yet.
/// - [error]: Stream emitted an error.
/// - [builder]: Stream has emitted data (or has initial data).
class ZenStreamQueryBuilder<T> extends StatelessWidget {
  final ZenStreamQuery<T> query;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function()? loading;
  final Widget Function(Object error)? error;
  final Widget Function()? empty; // Optional: for empty lists/iterables

  const ZenStreamQueryBuilder({
    super.key,
    required this.query,
    required this.builder,
    this.loading,
    this.error,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 1. Handle Error
      if (query.hasError) {
        if (error != null) {
          return error!(query.error.value!);
        }
        // Default error view if none provided
        return Center(
          child: Text(
            'Stream Error: ${query.error.value}',
            style: const TextStyle(color: Colors.red),
          ),
        );
      }

      // 2. Handle Loading (only if no data is available)
      // If we have data, we usually want to show it even if "reconnecting"
      if (query.isLoading.value && !query.hasData) {
        if (loading != null) {
          return loading!();
        }
        return const Center(child: CircularProgressIndicator());
      }

      // 3. Handle Data
      if (query.data.value != null) {
        final data = query.data.value as T;

        // Optional: Handle Empty State for Iterables
        if (empty != null && data is Iterable && data.isEmpty) {
          return empty!();
        }

        return builder(context, data);
      }

      // 4. Idle/Initializing (Fallback)
      if (loading != null) {
        return loading!();
      }
      return const SizedBox.shrink();
    });
  }
}
