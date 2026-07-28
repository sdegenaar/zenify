# Hierarchical Scopes (Flat Routing) Example

A comprehensive Flutter example demonstrating how to manage **Zenify's hierarchical scope inheritance** when using traditional, flat routing (`Navigator.push`).

> [!WARNING]
> **Zenify V2 Architecture Note:** 
> In Flutter, `Navigator.push` creates a "detached overlay" that breaks the widget tree. Because Zenify V2 relies on walking up the widget tree (`context.zenScope`) to discover parent scopes, detached routes cannot automatically inherit their parent's scope.
> 
> This example demonstrates the **Explicit Inheritance Pattern** required when using flat routing. For the **Canonical Zero-Config Pattern**, please see the `hierarchical_scopes_nested` example which uses `go_router` and `ShellRoute`.

## What This Example Demonstrates

This example showcases a real-world navigation scenario where:
- **Home** (entry point) provides basic navigation services.
- **Departments** inherits from Home and provides shared business services.
- **Department Details** inherits from the Departments scope.
- **Employee Profile** inherits from Department Details (deepest level).

## 🏗️ The "Flat Route" Challenge

When navigating from Departments to Department Details using standard `Navigator.push`, the new route is pushed as a sibling to the previous route in the widget tree, not a child.

To fix this, we must explicitly pass the `parentScope` via route arguments:

### 1. Passing the Parent Scope
```dart
// In DepartmentsController:
void navigateToDepartmentDetail(String departmentId, ZenScope? parentScope) {
  Navigator.pushNamed(
    context,
    AppRoutes.departmentDetail,
    arguments: {
      'departmentId': departmentId,
      'parentScope': parentScope, // 🔥 Explicitly passing the scope
    },
  );
}
```

### 2. Linking the Hierarchy
```dart
// In AppRoutes.onGenerateRoute:
case departmentDetail:
  final args = settings.arguments as Map<String, dynamic>?;
  final parentScope = args?['parentScope'] as ZenScope?;

  return MaterialPageRoute(
    builder: (_) => ZenRoute(
      moduleBuilder: () => DepartmentDetailModule(),
      page: DepartmentDetailPage(),
      scopeName: 'DepartmentDetailScope',
      parentScope: parentScope, // 🔥 Explicitly linking the hierarchy
    ),
  );
```

## Deep Hierarchical Access

Once the explicit links are established, the hierarchy works perfectly. The **Employee Profile** (deepest level) has access to the complete service hierarchy:

```dart
// From Home Scope
final navigationService = Zen.find<NavigationService>();

// From Departments Scope  
final apiService = Zen.find<ApiService>();
final departmentService = Zen.find<DepartmentService>();

// From Department Details Scope
final deptController = Zen.find<DepartmentDetailsController>();
```

## Running the Example

```bash
cd example/hierarchical_scopes_flat
flutter run
```

**Try this navigation flow:**
1. Start at Home
2. Navigate to "Departments"
3. Select a department (e.g., "Engineering")
4. Select an employee (e.g., "John Doe")
5. Check the "Debug Info" (bug icon in the AppBar) to see the complete service hierarchy properly linked via explicit `parentScope` arguments.
