import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:zenify_devtools/src/models/scope_data.dart';

/// Service for fetching scope data from the running app
class ScopeService {
  /// Get all scopes from the running app
  Future<List<ScopeData>> getAllScopes() async {
    try {
      // Use DevTools service manager to evaluate code in the running app
      final response = await serviceManager.callServiceExtensionOnMainIsolate(
        'ext.zenify.getScopes',
      );

      if (response.json == null) {
        return [];
      }

      final scopes = response.json!['scopes'] as List<dynamic>?;
      if (scopes == null) {
        return [];
      }

      return scopes
          .map((json) => ScopeData.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If extension not registered, return mock data for now
      return _getMockScopes();
    }
  }

  /// Mock data for development/testing when app doesn't have extension registered
  List<ScopeData> _getMockScopes() {
    return [
      ScopeData(
        id: 'root-123',
        name: 'RootScope',
        isDisposed: false,
        isRoot: true,
        controllers: [],
        services: ['AuthService', 'ThemeService', 'CartService'],
        others: [],
        children: [
          ScopeData(
            id: 'app-456',
            name: 'AppScope',
            parentId: 'root-123',
            parentName: 'RootScope',
            isDisposed: false,
            isRoot: false,
            controllers: ['AppController'],
            services: [],
            others: [],
            children: [
              ScopeData(
                id: 'feature-789',
                name: 'ProductsFeatureScope',
                parentId: 'app-456',
                parentName: 'AppScope',
                isDisposed: false,
                isRoot: false,
                controllers: [
                  'ProductListController',
                  'ProductDetailController',
                ],
                services: ['ProductService'],
                others: [],
                children: [],
              ),
              ScopeData(
                id: 'feature-101',
                name: 'CartFeatureScope',
                parentId: 'app-456',
                parentName: 'AppScope',
                isDisposed: false,
                isRoot: false,
                controllers: ['CartController'],
                services: [],
                others: [],
                children: [],
              ),
            ],
          ),
        ],
      ),
    ];
  }
}
