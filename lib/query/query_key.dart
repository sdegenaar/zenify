/// Utility to normalize query keys into stable strings
class QueryKey {
  /// Normalize a key into a stable string representation
  static String normalize(Object? key) {
    if (key == null) return 'null';
    if (key is String) return key;

    if (key is List) {
      return '[${key.map((e) {
        if (e is String) return "'$e'";
        if (e is List) return normalize(e);
        return e.toString();
      }).join(', ')}]';
    }

    // For other objects, rely on toString()
    // Users should override toString() for custom key objects
    return key.toString();
  }
}
