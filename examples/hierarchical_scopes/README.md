
# Hierarchical Scopes Example

A comprehensive Flutter example demonstrating **Zenify's hierarchical scope management** with automatic parent-child relationships, stack-based tracking, and proper memory management during navigation.

##  What This Example Demonstrates

This example showcases a real-world navigation scenario where:
- **Home** (entry point) with basic navigation services
- **Departments** inherits from Home and provides shared business services
- **Department Details** inherits from Departments scope
- **Employee Profile** inherits from Department Details (deepest level)

## 🏗️ App Structure
``` 
📁 Home (Entry Scope)
└── 📁 Departments (Child of Home)
    ├── 🔗 ApiService, CacheService, NavigationService (inherited)
    ├── 📦 DepartmentService, EmployeeService (shared business logic)
    └── 📁 Department Details (Child of Departments)
        ├── 🔗 All parent services available
        ├── 📦 DepartmentDetailsController
        └── 📁 Employee Profile (Child of Department Details)
            └── 🔗 Complete service hierarchy available
```
**Hierarchy Breakdown:**
- **Home**: Entry point with basic navigation services
- **Departments**: Inherits from Home + provides shared business services
- **Department Details**: Inherits from Departments scope
- **Employee Profile**: Inherits from Department Details (deepest level)

**Service Flow:**
- 🔗 = Inherited services from parent scopes
- 📦 = New services registered at this level
- 📁 = Scope/Feature boundary

##  Key Features Demonstrated

### **1. Stack-Based Scope Inheritance**
```dart
// Child scopes automatically inherit from parent scopes using stack tracking
ZenRoute(
  moduleBuilder: () => DepartmentDetailsModule(departmentId: departmentId),
  page: DepartmentDetailsPage(departmentId: departmentId),
  useParentScope: true, //  Auto-discovers parent from navigation stack
)
```

### **2. Automatic Service Sharing**
``` dart
// Services from parent scopes are automatically available in child scopes
class DepartmentDetailsModule extends ZenModule {
  @override
  void register(ZenScope scope) {
    // ApiService, CacheService automatically inherited from Departments scope
    final apiService = scope.find<ApiService>()!; // ✅ Available from parent
    final employeeService = scope.find<EmployeeService>()!; // ✅ Available from parent
    
    // Register department-specific controller
    scope.put<DepartmentDetailsController>(
      DepartmentDetailsController(apiService, employeeService)
    );
  }
}
```
### **3. Deep Hierarchical Access**
``` dart
// Employee Profile has access to the complete service hierarchy
class EmployeeProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Can access services from any level of the hierarchy
    final apiService = context.findInScope<ApiService>(); // From Home
    final departmentService = context.findInScope<DepartmentService>(); // From Departments
    final employeeService = context.findInScope<EmployeeService>(); // From Departments
    final controller = context.findInScope<EmployeeProfileController>(); // Local
    
    return Scaffold(/* ... */);
  }
}
```
### **4. Smart Memory Management**
- **Stack-based tracking** ensures proper parent-child relationships
- **Auto-dispose logic** prevents memory leaks during navigation
- **Hierarchical cleanup** when scopes are no longer needed

## ️ Project Structure
``` 
lib/
├── main.dart                          # App entry point
├── core/
│   └── app_routes.dart                # Navigation with hierarchical scopes
└── features/
    ├── home/
    │   ├── modules/home_module.dart    # Basic navigation services
    │   └── pages/home_page.dart        # Entry point with navigation
    ├── departments/
    │   ├── modules/departments_module.dart  # Shared business services
    │   └── pages/departments_page.dart      # Department list
    ├── department_detail/
    │   ├── modules/department_detail_module.dart  # Department-specific logic
    │   └── pages/department_detail_page.dart      # Department details & employees
    └── employee_profile/
        ├── modules/employee_profile_module.dart   # Employee-specific logic
        └── pages/employee_profile_page.dart       # Individual employee view
```
## Navigation Flow
### **1. Home → Departments**
``` dart
Navigator.pushNamed(context, AppRoutes.departments);
// Creates: Home -> Departments scope hierarchy
// Departments inherits: NavigationService from Home
// Departments adds: ApiService, CacheService, DepartmentService, EmployeeService
```
### **2. Departments → Department Details**
``` dart
Navigator.pushNamed(
  context, 
  AppRoutes.departmentDetail,
  arguments: {'departmentId': 'engineering'}
);
// Creates: Home -> Departments -> DepartmentDetails hierarchy
// DepartmentDetails inherits: All services from Departments
// DepartmentDetails adds: DepartmentDetailsController
```
### **3. Department Details → Employee Profile**
``` dart
Navigator.pushNamed(
  context,
  AppRoutes.employeeProfile,
  arguments: {
    'departmentId': 'engineering',
    'employeeId': 'john-doe'
  }
);
// Creates: Home -> Departments -> DepartmentDetails -> EmployeeProfile hierarchy
// EmployeeProfile has access to ALL services from the complete hierarchy
```
## Service Hierarchy Example
At the **Employee Profile** level, you have access to:
``` dart
// From Home Scope
final navigationService = context.findInScope<NavigationService>();

// From Departments Scope  
final apiService = context.findInScope<ApiService>();
final cacheService = context.findInScope<CacheService>();
final departmentService = context.findInScope<DepartmentService>();
final employeeService = context.findInScope<EmployeeService>();

// From Department Details Scope
final deptController = context.findInScope<DepartmentDetailsController>();

// From Employee Profile Scope (local)
final employeeController = context.findInScope<EmployeeProfileController>();
```
## Testing the Hierarchy
### **1. Service Accessibility Test**
Each page includes a **"Debug Info"** section showing:
- Current scope name and parent
- Available services from the hierarchy
- Scope stack depth
- Memory usage information

### **2. Navigation Persistence**
- Navigate deep into the hierarchy
- Use device back button or app navigation
- Verify services remain available during the session

### **3. Memory Management**
- Navigate between different departments
- Check that old department-specific data is cleaned up
- Verify shared services persist appropriately

## Debug Features
Enable debug logging to see scope management in action:
``` dart
// In main.dart
ZenConfig.enableDebugLogs = true;
```
**Sample Debug Output:**
``` 
 Created scope: HomeScope
 Scope stack push: HomeScope
 Found stack-based parent scope: HomeScope  
 Scope stack push: HomeScope -> DepartmentsScope
 Found stack-based parent scope: DepartmentsScope
 Scope stack push: HomeScope -> DepartmentsScope -> DepartmentDetailsScope
 Complete hierarchy: 3 levels deep
```
## Real-World Benefits
### **Memory Efficiency**
- Services are shared across related scopes
- Automatic cleanup when navigation paths change
- No duplicate service instances in the hierarchy

### **Maintainable Architecture**
- Clear service boundaries between features
- Predictable service availability based on navigation context
- Easy testing with isolated scope hierarchies

### **Developer Experience**
- No manual scope management required
- Automatic parent resolution using navigation stack
- Comprehensive debug information

## Running the Example
``` bash
cd examples/hierarchical_scopes
flutter run
```
**Try this navigation flow:**
1. Start at Home
2. Navigate to "Departments"
3. Select a department (e.g., "Engineering")
4. Select an employee (e.g., "John Doe")
5. Check the "Debug Info" section to see the complete service hierarchy

## Key Learnings
1. **`useParentScope: true`** enables automatic stack-based parent discovery
2. **Services flow down** the hierarchy - child scopes can access parent services
3. **Stack-based tracking** provides reliable parent-child relationships during navigation
4. **Hierarchical cleanup** prevents memory leaks while maintaining session state
5. **Debug logging** provides visibility into scope lifecycle and relationships

This example demonstrates how Zenify's hierarchical scope system provides powerful dependency injection for complex Flutter applications with deep navigation structures, automatic memory management, and clear service boundaries.
