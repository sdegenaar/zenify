import 'dart:async';
import '../../controllers/zen_controller.dart';
import '../../reactive/reactive.dart';
import '../core/zen_query_enums.dart';

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

  /// Callback before mutation executes (useful for optimistic updates).
  /// Returns a context object that is passed to onError and onSettled.
  final FutureOr<Object?> Function(TVariables variables)? onMutate;

  /// Callback on success
  final void Function(TData data, TVariables variables, Object? context)?
      onSuccess;

  /// Callback on error
  final void Function(Object error, TVariables variables, Object? context)?
      onError;

  /// Callback when mutation is finished (success or error)
  /// Useful for invalidating queries
  final void Function(
    TData? data,
    Object? error,
    TVariables variables,
    Object? context,
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
  }) {
    // AUTOMATIC CHILD CONTROLLER TRACKING
    // If a parent controller is currently initializing (onInit is running),
    // automatically register this mutation with it for automatic disposal
    if (ZenController.currentParentController != null) {
      ZenController.currentParentController!.trackController(this);
    }
  }

  /// Execute the mutation.
  ///
  /// You can provide call-time callbacks [onSuccess], [onError], and [onSettled]
  /// which will run *after* the mutation-level callbacks defined in the constructor.
  Future<TData?> mutate(
    TVariables variables, {
    void Function(TData data, TVariables variables)? onSuccess,
    void Function(Object error, TVariables variables)? onError,
    void Function(TData? data, Object? error, TVariables variables)? onSettled,
  }) async {
    if (isDisposed) {
      throw StateError('Mutation has been disposed');
    }

    // Reset state
    status.value = ZenMutationStatus.loading;
    _isLoadingNotifier?.value = true;
    error.value = null;
    update();

    Object? context;

    try {
      // Lifecycle: onMutate
      if (onMutate != null) {
        context = await onMutate!(variables);
      }

      // Execute mutation
      final result = await mutationFn(variables);

      if (isDisposed) return null;

      // Update state: Success
      data.value = result;
      status.value = ZenMutationStatus.success;
      _isLoadingNotifier?.value = false;
      update();

      // Lifecycle: onSuccess (Definition)
      this.onSuccess?.call(result, variables, context);
      // Lifecycle: onSuccess (Call-time)
      onSuccess?.call(result, variables);

      // Lifecycle: onSettled (Definition)
      this.onSettled?.call(result, null, variables, context);
      // Lifecycle: onSettled (Call-time)
      onSettled?.call(result, null, variables);

      return result;
    } catch (e) {
      if (isDisposed) return null;

      // Update state: Error
      error.value = e;
      status.value = ZenMutationStatus.error;
      _isLoadingNotifier?.value = false;
      update();

      // Lifecycle: onError (Definition)
      this.onError?.call(e, variables, context);
      // Lifecycle: onError (Call-time)
      onError?.call(e, variables);

      // Lifecycle: onSettled (Definition)
      this.onSettled?.call(null, e, variables, context);
      // Lifecycle: onSettled (Call-time)
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
