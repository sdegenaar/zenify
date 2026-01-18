import 'dart:async';
import 'dart:math';
import '../../controllers/zen_controller.dart';
import '../../reactive/reactive.dart';
import '../core/zen_query_enums.dart';

// Internal imports for offline support
import '../core/zen_query_cache.dart';
import '../queue/zen_mutation_queue.dart';
import '../queue/zen_mutation_job.dart';

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
  /// Unique key for this mutation.
  ///
  /// Required for offline support. If set, this mutation can be queued
  /// and replayed when the app comes back online.
  final String? mutationKey;

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
    this.mutationKey,
    this.onMutate,
    this.onSuccess,
    this.onError,
    this.onSettled,
  }) {
    // AUTOMATIC CHILD CONTROLLER TRACKING
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
      // 1. Lifecycle: onMutate
      // Run immediately (optimistic updates depend on this)
      if (onMutate != null) {
        context = await onMutate!(variables);
      }

      // 2. Check Offline / Queueing
      if (mutationKey != null && !ZenQueryCache.instance.isOnline) {
        return _queueOfflineMutation(variables);
      }

      // Execute mutation
      final result = await mutationFn(variables);

      if (isDisposed) return null;

      // Update state: Success
      data.value = result;
      status.value = ZenMutationStatus.success;
      _isLoadingNotifier?.value = false;
      update();

      // Lifecycle callbacks...
      this.onSuccess?.call(result, variables, context);
      onSuccess?.call(result, variables);

      this.onSettled?.call(result, null, variables, context);
      onSettled?.call(result, null, variables);

      return result;
    } catch (e) {
      if (isDisposed) return null;

      // Check if we should queue due to network error during execution
      // (Simple check for now, can be improved to check Exception type)
      if (mutationKey != null && !ZenQueryCache.instance.isOnline) {
        return _queueOfflineMutation(variables);
      }

      // Update state: Error
      error.value = e;
      status.value = ZenMutationStatus.error;
      _isLoadingNotifier?.value = false;
      update();

      // Lifecycle callbacks...
      this.onError?.call(e, variables, context);
      onError?.call(e, variables);

      this.onSettled?.call(null, e, variables, context);
      onSettled?.call(null, e, variables);

      return null;
    }
  }

  Future<TData?> _queueOfflineMutation(TVariables variables) async {
    // Attempt to serialize variables
    Map<String, dynamic> payload;
    try {
      if (variables is Map<String, dynamic>) {
        payload = variables;
      } else {
        // Try dynamic dispatch to toJson
        payload = (variables as dynamic).toJson();
      }
    } catch (_) {
      // Cannot serialize, abort queueing
      // Fallback to normal error
      // Or throw?
      // Log and return null (error state?)
      // Actually we'll just throw the original error or Offline error
      throw StateError(
          'Cannot queue offline mutation: variables must be Map<String, dynamic> or have toJson()');
    }

    final job = ZenMutationJob(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}',
      mutationKey: mutationKey!,
      action: ZenMutationAction.custom,
      payload: payload,
      createdAt: DateTime.now(),
    );

    ZenMutationQueue.instance.add(job);

    // Treat as "Pending" / "Optimistic Success"?
    // We'll set status to idle? Or keep previous?
    // For now, let's just log and return null.
    // Ideally we should have a 'queued' status.
    // For MVP transparency:
    error.value =
        'Mutation queued for offline replay'; // Not an exception object?
    status.value = ZenMutationStatus.idle; // Reset to idle
    update();

    return null;
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
