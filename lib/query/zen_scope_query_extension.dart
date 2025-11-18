import 'package:zenify/query/zen_query.dart';

import '../core/zen_scope.dart';
import 'zen_query_config.dart';

extension ZenScopeQueryExtension on ZenScope {
  /// Create and register a scoped query in one call
  ZenQuery<T> createQuery<T>({
    required String queryKey,
    required Future<T> Function() fetcher,
    ZenQueryConfig? config,
    T? initialData,
  }) {
    final query = ZenQuery<T>(
      queryKey: queryKey,
      fetcher: fetcher,
      config: config,
      initialData: initialData,
      scope: this, // Automatically scoped
    );
    put(query); // Automatically registered
    return query;
  }
}

// Usage:
// class ProductModule extends ZenModule {
//   @override
//   void register(ZenScope scope) {
//     scope.createQuery<Product>(  // ← Simpler!
//       queryKey: 'product:$productId',
//       fetcher: () => api.getProduct(productId),
//     );
//   }
// }
