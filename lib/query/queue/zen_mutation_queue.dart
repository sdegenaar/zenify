import 'dart:async';
import 'dart:collection';
import '../../core/zen_logger.dart';
import '../../query/core/zen_storage.dart';
import '../../query/core/zen_query_cache.dart';
import 'zen_mutation_job.dart';

/// Handler function for replaying mutations
typedef ZenMutationHandler = Future<dynamic> Function(
    Map<String, dynamic> payload);

/// Manages the offline mutation queue.
///
/// Stores failed mutations and replays them when the network returns.
class ZenMutationQueue {
  static final ZenMutationQueue instance = ZenMutationQueue._();
  ZenMutationQueue._();

  final Queue<ZenMutationJob> _queue = Queue<ZenMutationJob>();
  ZenStorage? _storage;
  bool _isProcessing = false;

  /// Subscription to the network connectivity stream.
  /// Stored so it can be cancelled when [setNetworkStream] is called again
  /// (e.g. after a hot-restart or re-init), preventing duplicate listeners.
  StreamSubscription<bool>? _networkSubscription;

  /// Get the number of pending mutations in the queue
  int get pendingCount => _queue.length;

  /// Get a list of pending mutation jobs (for debugging/devtools)
  List<ZenMutationJob> get pendingJobs => _queue.toList();

  /// Initialize the queue and restore from storage if available
  Future<void> init(ZenStorage? storage) async {
    _storage = storage;
    if (_storage != null) {
      await _restore();
    }
  }

  /// Set the network stream to listen for connectivity changes.
  ///
  /// Cancels any previous subscription before attaching to the new stream,
  /// ensuring that calling this method more than once (e.g. after a hot-restart
  /// or test re-init) does not accumulate duplicate listeners.
  void setNetworkStream(Stream<bool> stream) {
    _networkSubscription?.cancel();
    _networkSubscription = stream.listen((isOnline) {
      if (isOnline) {
        process();
      }
    });
  }

  /// Add a job to the queue
  void add(ZenMutationJob job) {
    _queue.add(job);
    _persist();
    ZenLogger.logDebug(
        'Mutation queued offline: ${job.mutationKey} (ID: ${job.id})');
  }

  /// Remove a job from the queue
  void remove(String id) {
    _queue.removeWhere((job) => job.id == id);
    _persist();
  }

  /// Process the queue (replay mutations)
  ///
  /// Replays queued mutations sequentially in strict FIFO order.
  /// If a mutation fails (due to network or execution error), processing stops immediately
  /// to prevent out-of-order execution in order-sensitive workloads (e.g. chat messages,
  /// financial transactions, document edits). The failed job remains at the head of the queue
  /// to be retried on the next reconnect.
  Future<void> process() async {
    if (_isProcessing || _queue.isEmpty || !ZenQueryCache.instance.isOnline) {
      return;
    }

    _isProcessing = true;
    ZenLogger.logDebug(
        'Processing offline mutation queue (${_queue.length} jobs)...');

    try {
      // Process strictly in order (FIFO)
      while (_queue.isNotEmpty && ZenQueryCache.instance.isOnline) {
        final job = _queue.first;

        try {
          await _executeJob(job);
          remove(job.id); // Success! Remove from queue.
        } catch (e) {
          ZenLogger.logError('Failed to replay mutation ${job.id}', e);
          // Stop on failure to preserve sequential ordering.
          // Remaining jobs will be processed on subsequent reconnect attempts.
          break;
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Map of mutation keys to handler functions
  final Map<String, ZenMutationHandler> _registry = {};

  /// Register mutation handlers
  ///
  /// Required for replaying offline mutations.
  void registerHandlers(Map<String, ZenMutationHandler> handlers) {
    _registry.addAll(handlers);
  }

  // -- Internals --

  Future<void> _executeJob(ZenMutationJob job) async {
    final handler = _registry[job.mutationKey];
    if (handler == null) {
      ZenLogger.logWarning(
          'No handler registered for mutation key: ${job.mutationKey}. Dropping job.');
      return;
    }

    ZenLogger.logDebug('Replaying mutation: ${job.mutationKey}');
    await handler(job.payload);
  }

  Future<void> _persist() async {
    if (_storage == null) return;
    final jsonList = _queue.map((e) => e.toJson()).toList();
    try {
      await _storage!.write('zen_mutation_queue', {'queue': jsonList});
    } catch (e) {
      ZenLogger.logWarning('Failed to persist mutation queue: $e');
    }
  }

  Future<void> _restore() async {
    if (_storage == null) return;
    try {
      final data = await _storage!.read('zen_mutation_queue');
      if (data != null && data['queue'] is List) {
        final list = data['queue'] as List;
        _queue.clear();
        for (final item in list) {
          _queue.add(ZenMutationJob.fromJson(item));
        }
        ZenLogger.logDebug('Restored ${_queue.length} mutations from storage');
      }
    } catch (e) {
      ZenLogger.logWarning('Failed to restore mutation queue: $e');
    }
  }
}
