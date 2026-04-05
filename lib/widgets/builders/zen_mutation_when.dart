import 'package:flutter/widgets.dart';
import '../../query/logic/zen_mutation.dart';
import '../../query/core/zen_query_enums.dart';

/// Convenience extension on [ZenMutation] for declarative UI building.
///
/// Useful for driving button loading states, inline form feedback,
/// or any UI element that reflects mutation progress.
///
/// Example — loading button:
/// ```dart
/// ElevatedButton(
///   onPressed: mutation.status.value == ZenMutationStatus.loading
///       ? null
///       : () => mutation.mutate(args),
///   child: mutation.when(
///     idle: () => const Text('Save'),
///     loading: () => const SizedBox(
///       width: 20,
///       height: 20,
///       child: CircularProgressIndicator(strokeWidth: 2),
///     ),
///     success: (_) => const Text('Saved!'),
///     error: (e) => const Text('Retry'),
///   ),
/// )
/// ```
extension ZenMutationWhenExtension<TData, TVariables>
    on ZenMutation<TData, TVariables> {
  /// Builds UI based on the current mutation state.
  ///
  /// - [idle]: shown before the mutation is triggered (required)
  /// - [loading]: shown while the mutation is running (defaults to [idle])
  /// - [success]: shown after a successful mutation (defaults to [idle])
  /// - [error]: shown after a failed mutation (defaults to [idle])
  Widget when({
    required Widget Function() idle,
    Widget Function()? loading,
    Widget Function(TData data)? success,
    Widget Function(Object error)? error,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([status, data, this.error]),
      builder: (context, _) {
        switch (status.value) {
          case ZenMutationStatus.loading:
            return loading?.call() ?? idle();
          case ZenMutationStatus.success:
            final result = data.value;
            return result != null ? (success?.call(result) ?? idle()) : idle();
          case ZenMutationStatus.error:
            final err = this.error.value;
            return err != null ? (error?.call(err) ?? idle()) : idle();
          case ZenMutationStatus.idle:
            return idle();
        }
      },
    );
  }
}
