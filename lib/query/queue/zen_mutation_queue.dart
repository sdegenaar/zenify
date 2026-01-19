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

  /// Set the network stream to listen for connectivity changes
  void setNetworkStream(Stream<bool> stream) {
    stream.listen((isOnline) {
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
          // Here we need a way to execute the job using the user's mutation logic.
          // Since we serialized data but not functions, we need a registry.
          // This is the hard part of offline mutations: "How to hydrate logic".
          // For now, we will expose a generic "onReplay" callback registry.

          await _executeJob(job);
          remove(job.id); // Success! Remove from queue.
        } catch (e) {
          ZenLogger.logError('Failed to replay mutation ${job.id}', e);
          // If deterministic error, remove? If network, stop processing?
          // If network error, we stop processing and wait for next reconnect.
          if (!ZenQueryCache.instance.isOnline) break;

          // If typical error, maybe move to back or Dead Letter Queue?
          // For simple implementation: Remove to prevent blocking?
          // Or keep and retry later?
          // Let's implement retry count limit.
          remove(job.id);
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
