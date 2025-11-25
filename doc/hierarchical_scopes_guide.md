# Hierarchical Scopes in Zenify

Zenify's hierarchical scope system provides powerful dependency injection and lifecycle management through parent-child scope relationships. This guide explains how to effectively use hierarchical scopes in your Flutter applications.

## Table of Contents
- [Quick Start](#quick-start)
- [Example App](#-example-app)
- [Overview](#overview)
- [Scope Types](#scope-types)
- [Creating Hierarchical Scopes](#creating-hierarchical-scopes)
- [Scope Inheritance](#scope-inheritance)
- [Automatic Cleanup](#automatic-cleanup)
- [Navigation Patterns](#navigation-patterns)
- [Best Practices](#best-practices)
- [Advanced Usage](#advanced-usage)
- [Debugging](#debugging)
- [Summary](#summary)

## Quick Start

Get started with hierarchical scopes in 3 simple steps:

```dart
// Step 1: Create your app module
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService());
    scope.put<AuthService>(AuthService());
  }
}

// Step 2: Create app scope (persistent)
ZenRoute(
  moduleBuilder: () => AppModule(),
  scopeName: 'AppScope',
  useParentScope: false,  // Creates root hierarchy
  autoDispose: false,     // Lives for entire app
  page: HomePage(),
)

// Step 3: Create feature scope (inherits from app)
ZenRoute(
  moduleBuilder: () => FeatureModule(),
  scopeName: 'FeatureScope',
  useParentScope: true,   // Inherits from AppScope
  autoDispose: true,      // Cleans up when leaving
  page: FeaturePage(),
)

// Access dependencies in your widgets
class FeaturePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authService = context.findInScope<AuthService>(); // From parent
    final featureService = context.findInScope<FeatureService>(); // From current
    
    return Scaffold(/* your UI */);
  }
}
```

> **See it in action**: Check out the complete [hierarchical_scopes example app](../examples/hierarchical_scopes) that demonstrates a real-world navigation scenario with deep scope hierarchies.
> 

## Example App
The [hierarchical_scopes example](../examples/hierarchical_scopes) provides a complete, runnable demonstration of hierarchical scopes in action. It showcases:
- **Real navigation flow**: Home → Departments → Department Details → Employee Profile
- **Service inheritance**: Each level inherits from its parent while adding new services
- **Memory management**: Automatic cleanup and scope disposal
- **Debug visualization**: See the scope hierarchy in real-time
``` bash
# Run the example
cd examples/hierarchical_scopes
flutter run
```
This example perfectly illustrates the concepts explained in this guide with working code you can explore and modify.
## Overview
Hierarchical scopes allow you to organize your application's dependencies in a tree-like structure where child scopes can access dependencies from their parent scopes. This enables:
- **Dependency Sharing**: Share common services across multiple features
- **Isolation**: Keep feature-specific dependencies separate
- **Automatic Cleanup**: Efficiently manage memory and resources
- **Navigation Support**: Scope lifecycles tied to route navigation

## Scope Types
### Root Scope
The foundation scope that's always available. Created automatically when Zenify initializes.
``` dart
// Access the root scope
final rootScope = Zen.rootScope;
```
### Persistent Scopes
Long-lived scopes that remain active until explicitly disposed or the app terminates.
``` dart
ZenRoute(
  scopeName: 'AppScope',
  autoDispose: false, // Explicitly persistent
  page: HomePage(),
)
```
### Auto-Dispose Scopes
Temporary scopes that automatically dispose when their associated widget is removed.
``` dart
ZenRoute(
  scopeName: 'FeatureScope',
  autoDispose: true, // Automatically disposed
  page: FeaturePage(),
)
```
## Creating Hierarchical Scopes
### Manual Scope Creation
``` dart
// Create parent scope
final parentScope = Zen.createScope(name: 'ParentScope');

// Create child scope that inherits from parent
final childScope = parentScope.createChild(name: 'ChildScope');
```
### Using ZenRoute for Scope Management
``` dart
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService());
    scope.put<AuthService>(AuthService());
  }
}

class FeatureModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Can access DatabaseService and AuthService from parent
    final authService = scope.find<AuthService>()!;
    scope.put<FeatureService>(FeatureService(authService));
  }
}

// Application scope (persistent)
ZenRoute(
  moduleBuilder: () => AppModule(),
  page: HomePage(),
  scopeName: 'AppScope',
  useParentScope: false, // Creates new hierarchy root
  autoDispose: false,    // Persistent scope
)

// Feature scope (inherits from AppScope)
ZenRoute(
  moduleBuilder: () => FeatureModule(),
  page: FeaturePage(),
  scopeName: 'FeatureScope',
  useParentScope: true,  // Inherits from AppScope
  autoDispose: true,     // Auto-disposed when leaving feature
)
```
## Scope Inheritance
Child scopes automatically inherit all dependencies from their parent scopes:
``` dart
// Parent scope
class DatabaseModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService());
    scope.put<CacheService>(CacheService());
  }
}

// Child scope - can access parent dependencies
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Access parent dependencies
    final db = scope.find<DatabaseService>()!;
    final cache = scope.find<CacheService>()!;
    
    // Register child-specific dependencies
    scope.put<UserRepository>(UserRepository(db, cache));
    scope.put<UserController>(UserController());
  }
}
```
### Dependency Resolution Order
Dependencies are resolved in the following order:
1. Current scope
2. Parent scope
3. Grandparent scope
4. ... (up to root scope)
``` dart
// If multiple scopes have the same dependency type:
// Child scope version takes precedence
scope.put<Logger>(FeatureLogger()); // Child scope
parentScope.put<Logger>(AppLogger()); // Parent scope

// scope.find<Logger>() returns FeatureLogger
```
## Automatic Cleanup
Zenify provides intelligent scope cleanup to prevent memory leaks:
### Stack-Based Navigation Cleanup
When navigating back to a route with `useParentScope: false`, all intermediate scopes are automatically cleaned up:
``` dart
// Navigation flow:
// Home (useParentScope: false) 
//   → Departments (useParentScope: true)
//     → Department Detail (useParentScope: true)
//       → Employee (useParentScope: true)
//         → Back to Home (useParentScope: false)

// Result: Departments, Department Detail, and Employee scopes 
// are automatically disposed when returning to Home
```
### Auto-Dispose Rules
- **No parent + no explicit setting**: `autoDispose = true`
- **Has parent + no explicit setting**: `autoDispose = false`
- **Explicit autoDispose setting**: Overrides automatic detection
``` dart
// Auto-dispose = true (no parent)
ZenRoute(
  scopeName: 'TempScope',
  // autoDispose defaults to true
)

// Auto-dispose = false (has parent)
ZenRoute(
  scopeName: 'ChildScope',
  useParentScope: true,
  // autoDispose defaults to false
)

// Explicit override
ZenRoute(
  scopeName: 'ExplicitScope',
  useParentScope: true,
  autoDispose: true, // Explicit override
)
```
## Navigation Patterns
### Feature-Based Hierarchy
The [hierarchical_scopes example](../examples/hierarchical_scopes) demonstrates this exact pattern:
``` dart
// App Level - Persistent
ZenRoute(
  moduleBuilder: () => AppModule(),
  scopeName: 'AppScope',
  useParentScope: false,
  autoDispose: false,
)

// Feature Level - Semi-persistent
ZenRoute(
  moduleBuilder: () => DepartmentsModule(),
  scopeName: 'DepartmentsScope',
  useParentScope: true,
  autoDispose: false, // Persists during feature navigation
)

// Detail Level - Auto-dispose
ZenRoute(
  moduleBuilder: () => DepartmentDetailModule(),
  scopeName: 'DepartmentDetailScope',
  useParentScope: true,
  autoDispose: true, // Cleaned up when leaving detail
)
```
### Modal/Dialog Scopes
``` dart
// Temporary scope for modal content
showDialog(
  context: context,
  builder: (context) => ZenRoute(
    moduleBuilder: () => DialogModule(),
    page: CustomDialog(),
    scopeName: 'DialogScope',
    useParentScope: true,
    autoDispose: true, // Automatically cleaned up when dialog closes
  ),
);
```
## Best Practices
### 1. Design Clear Hierarchies
``` dart
// Good: Clear separation of concerns
AppScope (Database, Auth, Config)
├── DashboardScope (Dashboard services)
├── UserScope (User management)
│   ├── ProfileScope (Profile editing)
│   └── SettingsScope (User settings)
└── AdminScope (Admin features)
    ├── UserManagementScope
    └── ReportsScope
```
### 2. Use Appropriate Persistence
``` dart
// Application-wide services → Persistent
ZenRoute(
  scopeName: 'AppScope',
  autoDispose: false,
)

// Feature-specific services → Auto-dispose
ZenRoute(
  scopeName: 'FeatureScope',
  autoDispose: true,
)

// Navigation hubs → Semi-persistent
ZenRoute(
  scopeName: 'MainScope',
  autoDispose: false,
)
```
### 3. Minimize Scope Depth
``` dart
// Avoid excessive nesting
AppScope
├── FeatureScope (depth 1) ✅
│   └── DetailScope (depth 2) ✅
│       └── SubDetailScope (depth 3) ⚠️
│           └── DeepScope (depth 4) ❌ Too deep
```
### 4. Name Scopes Descriptively
``` dart
// Good
'UserManagementScope'
'DepartmentDetailScope'
'ShoppingCartScope'

// Avoid
'Scope1'
'TempScope'
'MyScope'
```
### 5. Common Patterns
#### Shared Services Pattern
``` dart
// Put shared services in parent scopes
class AppModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService()); // Shared
    scope.put<AuthService>(AuthService());         // Shared
    scope.put<ConfigService>(ConfigService());     // Shared
  }
}
```
#### Feature Isolation Pattern
``` dart
// Keep feature-specific dependencies separate
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    final db = scope.find<DatabaseService>()!; // From parent
    scope.put<UserRepository>(UserRepository(db)); // Feature-specific
    scope.put<UserController>(UserController());   // Feature-specific
  }
}
```
## Advanced Usage
### Custom Parent Resolution
``` dart
// Explicitly specify parent scope
final specificParent = Zen.find<ZenScope>(tag: 'SpecificScope');

ZenRoute(
  moduleBuilder: () => MyModule(),
  scopeName: 'CustomChildScope',
  parentScope: specificParent, // Use specific parent
)
```
### Scope Inspection
``` dart
// Check scope relationships
final currentScope = Zen.currentScope;
final parentScope = currentScope.parent;

// Get all dependencies in scope
final dependencies = currentScope.getAllDependencies();

// Check if scope contains specific instance
final containsService = currentScope.containsInstance(myService);
```
### Manual Scope Management
``` dart
// Create child scope manually
final childScope = parentScope.createChild(name: 'ManualChild');

// Register disposer
childScope.registerDisposer(() {
  print('Child scope is being disposed');
});

// Dispose when no longer needed
childScope.dispose();
```
## Debugging
### Enable Debug Logging
``` dart
void main() {
  ZenConfig.enableDebugLogs = true;
  Zen.init();
  runApp(MyApp());
}
```
### Inspect Hierarchy
``` dart
// Get current scope information
final currentScope = Zen.currentScope;
print('Current scope: ${currentScope.name}');
print('Parent scope: ${currentScope.parent?.name}');
print('Child scopes: ${currentScope.childScopes.length}');

// Check all registered services
final allServices = currentScope.getAllDependencies();
print('Registered services: ${allServices.length}');
```
### Common Debug Output
``` 
 Created scope: HomeScope (id: HomeScope-1234567890)
 Registered NavigationService (temporary)
 Created scope: DepartmentsScope (id: DepartmentsScope-1234567891)
 Registered ApiService (temporary)
 Registered CacheService (temporary)
 Found stack-based parent scope: HomeScope
```
### Using ScopeDebugPanel
The example app includes a widget that shows real-time scope information: `ScopeDebugPanel`
``` dart
// Add to any page for debugging
ScopeDebugPanel(
  initiallyExpanded: true,
  showInternalDetails: true,
)
```
## Summary
Hierarchical scopes in Zenify provide:
- **Structured Dependency Management**: Organize dependencies in logical hierarchies
- **Automatic Lifecycle Management**: Scopes are created and disposed as needed
- **Memory Efficiency**: Automatic cleanup prevents memory leaks
- **Navigation Integration**: Scope lifecycles align with route navigation
- **Flexibility**: Support for both persistent and temporary scopes
- **Stack-Based Tracking**: Reliable parent-child relationships through navigation

By following these patterns and best practices, you can build scalable Flutter applications with clean dependency management and efficient resource utilization. The [hierarchical_scopes example](../examples/hierarchical_scopes) demonstrates all these concepts in a working application you can study and extend.
