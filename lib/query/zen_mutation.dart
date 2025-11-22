import 'dart:async';
import '../controllers/zen_controller.dart';
import '../reactive/reactive.dart';

/// Status of a mutation
enum ZenMutationStatus {
  idle,
  loading,
  success,
  error,
}

/// A reactive mutation that manages async data updates (creates/updates/deletes)
///
/// Example:
/// ```dart
/// final loginMutation = ZenMutation<User, LoginArgs>(
///   mutationFn: (args) => api.login(args),
///   onSuccess: (user, args) => print('Logged in as ${user.name}'),
///   onError: (error, args) => print('Login failed: $error'),
/// );
///
/// // Trigger
/// loginMutation.mutate(LoginArgs('user', 'pass'));
/// ```
class ZenMutation<TData, TVariables> extends ZenController {
  /// Function that performs the mutation
  final Future<TData> Function(TVariables variables) mutationFn;

  /// Callback before mutation executes (useful for optimistic updates)
  final FutureOr<void> Function(TVariables variables)? onMutate;

  /// Callback on success
  final void Function(TData data, TVariables variables)? onSuccess;

  /// Callback on error
  final void Function(Object error, TVariables variables)? onError;

  /// Callback when mutation is finished (success or error)
  /// Useful for invalidating queries
  final void Function(
    TData? data,
    Object? error,
    TVariables variables,
  )? onSettled;

  /// Current status of the mutation
  final Rx<ZenMutationStatus> status = Rx(ZenMutationStatus.idle);

  /// Result data (null if not successful yet)
  final Rx<TData?> data = Rx(null);

  /// Current error (null if no error)
  final Rx<Object?> error = Rx(null);

  /// Whether the mutation is currently running
  RxBool get isLoading =>
      _isLoadingNotifier ??= RxBool(status.value == ZenMutationStatus.loading);
  RxBool? _isLoadingNotifier;

  /// Whether the mutation was successful
  bool get isSuccess => status.value == ZenMutationStatus.success;

  /// Whether the mutation failed
  bool get isError => status.value == ZenMutationStatus.error;

  ZenMutation({
    required this.mutationFn,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  });

  /// Execute the mutation
  Future<TData?> mutate(TVariables variables) async {
    if (isDisposed) {
      throw StateError('Mutation has been disposed');
    }

    // Reset state
    status.value = ZenMutationStatus.loading;
    _isLoadingNotifier?.value = true;
    error.value = null;
    update();

    try {
      // Lifecycle: onMutate
      if (onMutate != null) {
        await onMutate!(variables);
      }

      // Execute mutation
      final result = await mutationFn(variables);

      if (isDisposed) return null;

      // Update state: Success
      data.value = result;
      status.value = ZenMutationStatus.success;
      _isLoadingNotifier?.value = false;
      update();

      // Lifecycle: onSuccess
      onSuccess?.call(result, variables);
      // Lifecycle: onSettled
      onSettled?.call(result, null, variables);

      return result;
    } catch (e) {
      if (isDisposed) return null;

      // Update state: Error
      error.value = e;
      status.value = ZenMutationStatus.error;
      _isLoadingNotifier?.value = false;
      update();

      // Lifecycle: onError
      onError?.call(e, variables);
      // Lifecycle: onSettled
      onSettled?.call(null, e, variables);

      // We generally don't rethrow here to prevent breaking UI event handlers,
      // as the error state is captured in the reactive variable.
      // If the caller awaits .mutate(), they can check .isError
      return null;
    }
  }

  /// Reset the mutation state to idle
  void reset() {
    data.value = null;
    error.value = null;
    status.value = ZenMutationStatus.idle;
    _isLoadingNotifier?.value = false;
    update();
  }

  @override
  void onClose() {
    status.dispose();
    data.dispose();
    error.dispose();
    _isLoadingNotifier?.dispose();
    super.onClose();
  }
}
