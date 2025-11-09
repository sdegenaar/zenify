// lib/di/zen_refs.dart
import '../core/zen_scope.dart';
import 'zen_di.dart';

/// Universal reference to any dependency - one type for all use cases
///
/// Examples:
/// ```dart
/// final authRef = Ref<AuthService>();
/// final userRef = Ref<UserService>(tag: 'premium');
/// final scopedRef = Ref<CheckoutService>(scope: checkoutScope);
/// ```
class Ref<T> {
  final String? tag;
  final ZenScope? scope;

  const Ref({this.tag, this.scope});

  ZenScope get _targetScope => scope ?? Zen.rootScope;

  /// Get the instance (throws if not found)
  T call() => find();

  /// Get the instance (throws if not found)
  T find() => _targetScope.findRequired<T>(tag: tag);

  /// Find the instance (returns null if not found)
  T? findOrNull() => _targetScope.find<T>(tag: tag);

  /// Delete the instance
  bool delete({bool force = false}) {
    return _targetScope.delete<T>(tag: tag, force: force);
  }

  /// Check if instance exists
  bool exists() => _targetScope.exists<T>(tag: tag);

  /// Register an eager instance
  T put(T instance, {bool isPermanent = false}) {
    return _targetScope.put<T>(
      instance,
      tag: tag,
      isPermanent: isPermanent,
    );
  }

  /// Register a lazy factory
  void putLazy(T Function() factory, {bool isPermanent = false}) {
    _targetScope.putLazy<T>(factory, tag: tag, isPermanent: isPermanent);
  }

  @override
  String toString() => 'Ref<$T>${tag != null ? '($tag)' : ''}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ref<T> && other.tag == tag && other.scope == scope;

  @override
  int get hashCode => Object.hash(T, tag, scope);
}
