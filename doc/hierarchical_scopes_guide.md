# Hierarchical Scopes in Zenify

Zenify's hierarchical scope system provides powerful dependency injection and lifecycle management through parent-child scope relationships. With the new **widget tree-based architecture**, scopes are now simpler, more intuitive, and fully integrated with Flutter's lifecycle.

## Table of Contents
- [What's New](#whats-new)
- [Quick Start](#quick-start)
- [Example App](#example-app)
- [Overview](#overview)
- [Widget Tree-Based Architecture](#widget-tree-based-architecture)
- [Creating Hierarchical Scopes](#creating-hierarchical-scopes)
- [Scope Inheritance](#scope-inheritance)
- [Automatic Cleanup](#automatic-cleanup)
- [Navigation Patterns](#navigation-patterns)
- [Best Practices](#best-practices)
- [Advanced Usage](#advanced-usage)
- [Debugging](#debugging)
- [Migration from Legacy API](#migration-from-legacy-api)
- [Summary](#summary)

## What's New

**Phase 1 Refactoring** (Current Version) brings major simplifications:

✨ **Hybrid Discovery Architecture**
- Parent scopes discovered automatically via `InheritedWidget` (within routes)
- Navigation gap bridged via `Zen.currentScope` pointer (across routes)
- Optional explicit `parentScope` parameter for full control
- Scopes dispose automatically when widgets are removed

🚀 **Simpler API**
- ❌ Removed: `useParentScope` parameter (automatic via hybrid discovery)
- ❌ Removed: `autoDispose` parameter (automatic widget disposal)
- ✅ Optional: `parentScope` parameter for explicit parent (e.g., clean routes)
- ✅ Just wrap with `ZenRoute` or `ZenScopeWidget`!

📦 **Cleaner Codebase**
- 80% reduction in scope management complexity
- Removed complex ZenScopeManager and ZenScopeStackTracker
- Simple bridge pattern solves Navigator's widget tree gap

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

// Step 2: Create app scope at root
ZenRoute(
  moduleBuilder: () => AppModule(),
  page: HomePage(),
  scopeName: 'AppScope',  // Optional (for debugging)
)

// Step 3: Create feature scope (automatically inherits from parent!)
ZenRoute(
  moduleBuilder: () => FeatureModule(),
  page: FeaturePage(),
  scopeName: 'FeatureScope',
  // Parent scope is automatically discovered from widget tree!
  // Disposal is automatic when this route is popped!
)

// Access dependencies in your widgets
class FeaturePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Access from any ancestor scope in widget tree
    final authService = context.findInScope<AuthService>(); // From parent
    final featureService = context.findInScope<FeatureService>(); // From current

    return Scaffold(/* your UI */);
  }
}
```

> **See it in action**: Check out the complete [hierarchical_scopes example app](../example/hierarchical_scopes) that demonstrates a real-world navigation scenario with deep scope hierarchies.

## Example App

The [hierarchical_scopes example](../example/hierarchical_scopes) provides a complete, runnable demonstration of hierarchical scopes in action. It showcases:

- **Real navigation flow**: Home → Departments → Department Details → Employee Profile
- **Automatic inheritance**: Each level automatically inherits from its parent
- **Automatic cleanup**: Scopes dispose when routes are popped
- **Debug visualization**: See the scope hierarchy in real-time

```bash
# Run the example
cd example/hierarchical_scopes
flutter run
```

This example perfectly illustrates the concepts explained in this guide with working code you can explore and modify.

## Overview

Hierarchical scopes allow you to organize your application's dependencies in a tree-like structure where child scopes can access dependencies from their parent scopes. This enables:

- **Dependency Sharing**: Share common services across multiple features
- **Isolation**: Keep feature-specific dependencies separate
- **Automatic Cleanup**: Efficiently manage memory and resources
- **Navigation Support**: Scope lifecycles tied to Flutter's widget tree

## Widget Tree-Based Architecture

### How It Works

Zenify uses a **hybrid discovery strategy** that combines widget tree discovery with a navigation bridge:

1. **Automatic Parent Discovery (3 fallback levels)**
   - **Level 1**: Explicit `parentScope` parameter (when provided)
   - **Level 2**: Widget tree via `InheritedWidget` (for nested widgets)
   - **Level 3**: `Zen.currentScope` bridge (for Navigator routes)
   - Works automatically in 99% of cases, with explicit control when needed

2. **The Navigation Bridge**
   - Flutter's `Navigator` pushes routes as siblings, breaking the widget tree
   - `Zen.currentScope` acts as a pointer to bridge this gap
   - When Route A creates a scope, it becomes the "current" scope
   - When Route B is pushed, it finds Route A's scope via this pointer
   - Automatic and transparent - you don't need to think about it!

3. **Automatic Lifecycle**
   - Scopes are created when widgets are built
   - Scopes are disposed when widgets are removed
   - Parent scope is restored as "current" on disposal
   - Follows Flutter's natural lifecycle

### Visual Representation

```dart
MaterialApp
  └─ ZenRoute (AppScope)           ← Root scope
      └─ HomePage
          └─ ZenRoute (FeatureScope)   ← Automatically finds AppScope as parent
              └─ FeaturePage
                  └─ ZenRoute (DetailScope)  ← Automatically finds FeatureScope as parent
                      └─ DetailPage
```

The widget tree **IS** the scope hierarchy!

## Creating Hierarchical Scopes

### Using ZenRoute (Recommended)

`ZenRoute` is the primary way to create scoped dependencies for entire routes:

```dart
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
    // Access parent dependencies
    final authService = scope.find<AuthService>()!;
    scope.put<FeatureService>(FeatureService(authService));
  }
}

// Application scope
ZenRoute(
  moduleBuilder: () => AppModule(),
  page: HomePage(),
  scopeName: 'AppScope',  // Optional name for debugging
)

// Feature scope - automatically inherits from AppScope
ZenRoute(
  moduleBuilder: () => FeatureModule(),
  page: FeaturePage(),
  scopeName: 'FeatureScope',
)
```

### Using ZenScopeWidget (For Partial Widget Trees)

Use `ZenScopeWidget` when you need a scope for part of a widget tree (not a full route):

```dart
ZenScopeWidget(
  moduleBuilder: () => SubFeatureModule(),
  scopeName: 'SubFeatureScope',
  child: SubFeatureWidget(),
)
```

### Manual Scope Creation (Advanced)

For programmatic scope creation outside the widget tree:

```dart
// Create parent scope
final parentScope = Zen.createScope(name: 'ParentScope');

// Create child scope
final childScope = parentScope.createChild(name: 'ChildScope');
```

## Scope Inheritance

Child scopes automatically inherit all dependencies from their parent scopes via the widget tree:

```dart
// Parent module
class DatabaseModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    scope.put<DatabaseService>(DatabaseService());
    scope.put<CacheService>(CacheService());
  }
}

// Child module - automatically has access to parent dependencies
class UserModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // Access parent dependencies (searches up the widget tree)
    final db = scope.find<DatabaseService>()!;
    final cache = scope.find<CacheService>()!;

    // Register child-specific dependencies
    scope.put<UserRepository>(UserRepository(db, cache));
    scope.put<UserController>(UserController());
  }
}
```

### Dependency Resolution Order

Dependencies are resolved by searching up the widget tree:

1. Current scope
2. Parent scope (from InheritedWidget)
3. Grandparent scope (from InheritedWidget)
4. ... (up to root scope)

```dart
// If multiple scopes have the same dependency type:
// Closest scope takes precedence (like CSS)
scope.put<Logger>(FeatureLogger());        // Child scope
parentScope.put<Logger>(AppLogger());      // Parent scope

// scope.find<Logger>() returns FeatureLogger (closest match)
```

## Automatic Cleanup

### Widget Disposal = Scope Disposal

Scopes are automatically disposed when their owner widget is removed from the tree:

```dart
// Navigation flow:
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ZenRoute(
    moduleBuilder: () => FeatureModule(),
    page: FeaturePage(),
    scopeName: 'FeatureScope',
  ),
));

// When user presses back button:
// → FeaturePage widget is disposed
// → FeatureScope is automatically disposed
// → All dependencies in FeatureScope are cleaned up
```

### Nested Route Cleanup

When navigating back through multiple routes, all intermediate scopes are automatically cleaned up:

```dart
// Navigation flow:
Home (HomeScope)
  → Departments (DepartmentsScope)
    → Department Detail (DetailScope)
      → Employee (EmployeeScope)
        → Back to Home

// Result: DepartmentsScope, DetailScope, and EmployeeScope
// are all automatically disposed when returning to Home
```

### Persistent Scopes

For scopes that should outlive their widgets, use `Zen.rootScope`:

```dart
void main() {
  // Register global services in root scope
  Zen.rootScope.put<AppConfig>(AppConfig());
  Zen.rootScope.put<GlobalService>(GlobalService());

  runApp(MyApp());
}

// Root scope services are available everywhere
// and persist for the entire app lifetime
```

## Navigation Patterns

### Feature-Based Hierarchy

The [hierarchical_scopes example](../example/hierarchical_scopes) demonstrates this pattern:

```dart
// App Level - Wraps entire app
MaterialApp(
  home: ZenRoute(
    moduleBuilder: () => AppModule(),
    page: HomePage(),
    scopeName: 'AppScope',
  ),
)

// Feature Level - Nested inside app
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ZenRoute(
    moduleBuilder: () => DepartmentsModule(),
    page: DepartmentsPage(),
    scopeName: 'DepartmentsScope',
    // Automatically inherits from AppScope!
  ),
));

// Detail Level - Nested inside feature
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ZenRoute(
    moduleBuilder: () => DepartmentDetailModule(),
    page: DepartmentDetailPage(),
    scopeName: 'DepartmentDetailScope',
    // Automatically inherits from DepartmentsScope!
  ),
));
```

### Modal/Dialog Scopes

```dart
// Temporary scope for modal content
showDialog(
  context: context,
  builder: (context) => ZenRoute(
    moduleBuilder: () => DialogModule(),
    page: CustomDialog(),
    scopeName: 'DialogScope',
    // Inherits from current scope
    // Disposed when dialog closes
  ),
);
```

### Clean Routes (Explicit Parent)

Use the `parentScope` parameter when you want explicit control over parent inheritance:

```dart
// Clean route with NO inheritance (only global services from root)
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ZenRoute(
    parentScope: Zen.rootScope,  // Explicit: only inherit from root
    moduleBuilder: () => StandaloneModule(),
    page: StandalonePage(),
    scopeName: 'StandaloneScope',
  ),
));

// Custom parent (skip immediate parent, use specific ancestor)
final appScope = Zen.rootScope;  // Or find specific scope
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ZenRoute(
    parentScope: appScope,  // Explicit: inherit from app scope
    moduleBuilder: () => CustomModule(),
    page: CustomPage(),
  ),
));
```

### Tabbed Navigation

```dart
// Each tab can have its own scope
class TabbedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(tabs: [/*...*/]),
          Expanded(
            child: TabBarView(
              children: [
                ZenScopeWidget(
                  moduleBuilder: () => Tab1Module(),
                  child: Tab1View(),
                ),
                ZenScopeWidget(
                  moduleBuilder: () => Tab2Module(),
                  child: Tab2View(),
                ),
                ZenScopeWidget(
                  moduleBuilder: () => Tab3Module(),
                  child: Tab3View(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## Best Practices

### 1. Design Clear Hierarchies

```dart
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

### 2. Use Root Scope for Global Services

```dart
// Application-wide services → Root scope
void main() {
  Zen.rootScope.put<AppConfig>(AppConfig());
  Zen.rootScope.put<DatabaseService>(DatabaseService());
  Zen.rootScope.put<AuthService>(AuthService());

  runApp(MyApp());
}
```

### 3. Use Route Scopes for Features

```dart
// Feature-specific services → ZenRoute
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ZenRoute(
    moduleBuilder: () => FeatureModule(),
    page: FeaturePage(),
    scopeName: 'FeatureScope',
  ),
));
```

### 4. Minimize Scope Depth

```dart
// Avoid excessive nesting
AppScope
├── FeatureScope (depth 1) ✅
│   └── DetailScope (depth 2) ✅
│       └── SubDetailScope (depth 3) ⚠️
│           └── DeepScope (depth 4) ❌ Too deep
```

### 5. Name Scopes Descriptively

```dart
// Good
'UserManagementScope'
'DepartmentDetailScope'
'ShoppingCartScope'

// Avoid
'Scope1'
'TempScope'
'MyScope'
```

### 6. Common Patterns

#### Shared Services Pattern

```dart
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

```dart
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

### Accessing Scopes from Context

```dart
// Get current scope
final currentScope = context.zenScope;

// Get current scope (throws if not found)
final requiredScope = context.zenScopeRequired;

// Find dependency in current scope
final service = context.findInScope<MyService>();

// Find dependency or return null
final optionalService = context.findInScopeOrNull<MyService>();
```

### Scope Inspection

```dart
// Check scope relationships
final currentScope = context.zenScope;
final parentScope = currentScope?.parent;

// Get all dependencies in scope
final dependencies = currentScope?.getAllDependencies();

// Check children
final childScopes = currentScope?.childScopes;
```

### Manual Scope Management

```dart
// Create child scope manually (outside widget tree)
final parentScope = Zen.rootScope;
final childScope = parentScope.createChild(name: 'ManualChild');

// Register dependencies
childScope.put<MyService>(MyService());

// Dispose when no longer needed
childScope.dispose();
```

## Debugging

### Enable Debug Logging

```dart
void main() {
  ZenConfig.enableDebugLogs = true;
  Zen.init();
  runApp(MyApp());
}
```

### Inspect Hierarchy

```dart
// Get current scope information from context
final currentScope = context.zenScope;
print('Current scope: ${currentScope?.name}');
print('Parent scope: ${currentScope?.parent?.name}');
print('Child scopes: ${currentScope?.childScopes.length}');

// Get all scopes (from root hierarchy)
final allScopes = ZenDebug.allScopes;
print('Total active scopes: ${allScopes.length}');
```

### Common Debug Output

```
✨ Created scope: HomeScope with parent: RootScope
📦 Registered module: HomeModule
✅ Initialized module: HomeModule
✨ Created scope: DepartmentsScope with parent: HomeScope
📦 Registered module: DepartmentsModule
✅ Initialized module: DepartmentsModule
🗑️ Scope disposed: DepartmentsScope
🗑️ Scope disposed: HomeScope
```

### Using Debug Dialog

The example app includes a debug dialog that shows real-time scope information:

```dart
// Tap debug icon to open dialog
FloatingActionButton(
  onPressed: () {
    showDialog(
      context: context,
      builder: (context) => const DebugDialog(),
    );
  },
  child: const Icon(Icons.developer_mode),
)
```

## Migration from Legacy API

If you're upgrading from an older version, here's what changed:

### Before (Legacy)

```dart
// Old API - complex parameters
ZenRoute(
  moduleBuilder: () => FeatureModule(),
  page: FeaturePage(),
  scopeName: 'FeatureScope',
  useParentScope: true,        // ❌ Removed
  autoDispose: true,           // ❌ Removed
  parentScope: specificScope,  // ❌ Removed
)
```

### After (New)

```dart
// New API - clean and simple
ZenRoute(
  moduleBuilder: () => FeatureModule(),
  page: FeaturePage(),
  scopeName: 'FeatureScope',
  // Parent discovery is automatic!
  // Disposal is automatic!
)
```

### Key Changes

| Old API | New API | Notes |
|---------|---------|-------|
| `useParentScope: true` | (automatic) | Parent discovered from widget tree |
| `autoDispose: true` | (automatic) | Scope disposed when widget disposed |
| `parentScope: scope` | (automatic) | Uses nearest ancestor scope |
| Manual cleanup | (automatic) | Flutter handles lifecycle |

### Migration Steps

1. **Remove old parameters**:
   - Delete `useParentScope` parameters
   - Delete `autoDispose` parameters
   - Delete `parentScope` parameters

2. **Update scope access**:
   - Use `context.zenScope` instead of `ZenScopeManager` calls
   - Use `ZenDebug.allScopes` instead of `ZenScopeManager.getAllScopes()`

3. **Test your app**:
   - Verify scope inheritance works correctly
   - Check that scopes dispose when routes are popped
   - Ensure no memory leaks

## Summary

Hierarchical scopes in Zenify provide:

- **Widget Tree Integration**: Scopes are managed by Flutter's widget tree
- **Automatic Parent Discovery**: No manual configuration required
- **Automatic Lifecycle**: Scopes created and disposed with widgets
- **Memory Efficiency**: Automatic cleanup prevents memory leaks
- **Simplified API**: 80% reduction in scope management code
- **Type Safety**: Compile-time safety for dependency access

### Quick Reference

```dart
// Create root-level scope
MaterialApp(
  home: ZenRoute(
    moduleBuilder: () => AppModule(),
    page: HomePage(),
  ),
)

// Create child scope (inherits automatically)
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ZenRoute(
    moduleBuilder: () => FeatureModule(),
    page: FeaturePage(),
  ),
));

// Access dependencies
final service = context.findInScope<MyService>();

// Access current scope
final scope = context.zenScope;
```

By following these patterns and best practices, you can build scalable Flutter applications with clean dependency management and efficient resource utilization. The [hierarchical_scopes example](../example/hierarchical_scopes) demonstrates all these concepts in a working application you can study and extend.
