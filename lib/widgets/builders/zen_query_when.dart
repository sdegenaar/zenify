import 'package:flutter/widgets.dart';
import '../../query/logic/zen_query.dart';
import 'zen_query_builder.dart';

/// Convenience extensions on [ZenQuery] for declarative UI building.
extension ZenQueryWhenExtension<T> on ZenQuery<T> {
  /// Builds UI declaratively based on the query state.
  ///
  /// A concise alternative to [ZenQueryBuilder] for common cases.
  ///
  /// Example:
  /// ```dart
  /// userQuery.when(
  ///   data: (user) => UserCard(user),
  ///   loading: () => const CircularProgressIndicator(),
  ///   error: (e, retry) => ErrorView(e, onRetry: retry),
  /// )
  /// ```
  ///
  /// All parameters except [data] are optional. Default fallbacks are used
  /// when a builder is not provided:
  /// - [loading]: `CircularProgressIndicator`
  /// - [error]: A basic error message with a retry button
  /// - [idle]: `SizedBox.shrink()`
  Widget when({
    required Widget Function(T data) data,
    Widget Function()? loading,
    Widget Function(Object error, VoidCallback retry)? error,
    Widget Function()? idle,
    bool autoFetch = true,
    bool showStaleData = true,
  }) {
    return ZenQueryBuilder<T>(
      query: this,
      builder: (context, value) => data(value),
      loading: loading,
      error: error,
      idle: idle,
      autoFetch: autoFetch,
      showStaleData: showStaleData,
    );
  }
}
