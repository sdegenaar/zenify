/// Utility methods for Zenify
class ZenUtils {
  ZenUtils._();

  /// Checks if two objects are structurally equal.
  ///
  /// Recursively compares Maps and Lists.
  /// Fallback to `==` for other types.
  static bool structuralEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;

    if (a is List && b is List) {
      return _listEquals(a, b);
    }

    if (a is Map && b is Map) {
      return _mapEquals(a, b);
    }

    if (a is Set && b is Set) {
      return _setEquals(a, b);
    }

    return a == b;
  }

  static bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!structuralEquals(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!structuralEquals(a[key], b[key])) return false;
    }
    return true;
  }

  static bool _setEquals(Set a, Set b) {
    if (a.length != b.length) return false;
    return a.containsAll(b) && b.containsAll(a);
  }

  /// Performs structural sharing on data.
  ///
  /// If [oldData] and [newData] are structurally equal, returns [oldData]
  /// to preserve object reference and prevent unnecessary rebuilds.
  /// Otherwise, returns [newData].
  static T shareStructure<T>(T oldData, T newData) {
    if (structuralEquals(oldData, newData)) {
      return oldData;
    }
    return newData;
  }
}
