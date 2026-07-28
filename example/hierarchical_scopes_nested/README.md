# Hierarchical Scopes (Nested Routing) Example

A comprehensive Flutter example demonstrating the **Canonical Zero-Config** approach to Zenify's hierarchical scope inheritance, powered by `go_router` and nested navigation (`ShellRoute`).

> [!TIP]
> **Zenify V2 Architecture Note:** 
> In Flutter, standard `Navigator.push` creates "detached overlays" that break the widget tree, requiring you to manually pass `parentScope` arguments between routes (as seen in the `hierarchical_scopes_flat` example).
> 
> By using nested routing (like `ShellRoute` in `go_router`), new routes are rendered *inside* the existing widget tree. Because the widget tree remains intact, Zenify V2 can automatically walk up the tree to discover parent scopes! **Zero boilerplate. Zero manual scope passing.**

## What This Example Demonstrates

This example showcases a real-world navigation scenario where:
- **Home** (entry point) provides basic navigation services.
- **Departments** inherits from Home and provides shared business services.
- **Department Details** inherits from the Departments scope automatically.
- **Employee Profile** inherits from Department Details automatically (deepest level).

## 🏗️ The "Nested Route" Magic

Because we use `ShellRoute`, the `DepartmentsScope` is placed high up in the widget tree, and all sub-routes (`/departments/detail/:id`) are rendered *inside* of it. 

### 1. The ShellRoute Configuration
```dart
// In AppRoutes.dart:
ShellRoute(
  builder: (context, state, child) {
    // 🔥 We provide the scope ONCE at the Shell level
    return ZenRoute(
      moduleBuilder: () => DepartmentsModule(),
      scopeName: 'DepartmentsScope',
      child: child, // All child routes render inside this tree!
    );
  },
  routes: [
    GoRoute(
      path: '/departments',
      builder: (context, state) => const DepartmentsPage(),
    ),
    GoRoute(
      path: '/departments/detail/:deptId',
      builder: (context, state) {
        // 🔥 Zero Config! No need to explicitly pass `parentScope`.
        // ZenRoute natively discovers the DepartmentsScope from the widget tree!
        return ZenRoute(
          moduleBuilder: () => DepartmentDetailModule(state.pathParameters['deptId']!),
          scopeName: 'DepartmentDetailScope',
          page: DepartmentDetailPage(departmentId: state.pathParameters['deptId']!),
        );
      },
    ),
  ],
)
```

### 2. Clean Business Logic
Because the widget tree is intact, your controllers and UI don't need to know anything about Zenify scopes when navigating:

```dart
// In DepartmentsController (Clean & Simple):
void navigateToDepartmentDetail(String departmentId) {
  // We just navigate normally. No `parentScope` boilerplate required!
  _navigationService.navigateTo('/departments/detail/$departmentId');
}
```

## Deep Hierarchical Access

Everything "just works". The **Employee Profile** (deepest level) has access to the complete service hierarchy automatically:

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
cd example/hierarchical_scopes_nested
flutter run
```

**Try this navigation flow:**
1. Start at Home
2. Navigate to "Departments"
3. Select a department (e.g., "Engineering")
4. Select an employee (e.g., "John Doe")
5. Check the "Debug Info" (bug icon in the AppBar) to see the complete service hierarchy seamlessly linked together without any explicit configuration!
