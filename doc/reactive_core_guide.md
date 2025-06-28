
# Reactive Core Guide

## Overview

Zenify's reactive system provides a powerful, efficient, and Flutter-optimized approach to state management. Built on top of Flutter's `ValueNotifier`, it offers automatic UI updates, minimal rebuilds, and intuitive APIs for managing application state.

## Table of Contents
- [Quick Start](#quick-start)
- [Core Concepts](#core-concepts)
- [Reactive Types](#reactive-types)
- [Creating Reactive Values](#creating-reactive-values)
- [Value Access Patterns](#value-access-patterns)
- [Reactive Collections](#reactive-collections)
- [Computed Values](#computed-values)
- [Async Reactive Values](#async-reactive-values)
- [Performance Optimization](#performance-optimization)
- [Best Practices](#best-practices)
- [Advanced Usage](#advanced-usage)
- [Testing](#testing)
- [Migration Guide](#migration-guide)

## Quick Start

Get started with Zenify's reactive system in 3 simple steps:

```dart
// Step 1: Create reactive values
class CounterController extends ZenController {
  // Simple reactive value
  final count = 0.obs();
  
  // Reactive collections
  final items = <String>[].obs();
  
  // Computed values
  String get countDisplay => 'Count: ${count.value}';
}

// Step 2: Update values
void increment() {
  count.value++; // Triggers reactive updates
}

void addItem(String item) {
  items.add(item); // Reactive collection update
}

// Step 3: Use in UI with automatic rebuilds
class CounterView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.find<CounterController>();
    
    return Obx(() => Column(
      children: [
        Text('${controller.count.value}'), // Auto-rebuilds on change
        ...controller.items.map((item) => Text(item)), // Reactive list
      ],
    ));
  }
}
```
```
## Core Concepts
### 1. **Reactive Values**
Values that automatically notify listeners when they change, enabling automatic UI updates.
``` dart
final name = 'John'.obs();        // Rx<String>
final age = 25.obs();             // Rx<int>
final isActive = true.obs();      // RxBool
final items = <String>[].obs();   // RxList<String>
```
### 2. **Observers**
Widgets or functions that listen to reactive values and automatically update when values change.
``` dart
// UI automatically rebuilds when count changes
Obx(() => Text('Count: ${count.value}'))
```
### 3. **Reactivity Chain**
Changes propagate automatically through the reactive system without manual notification.
``` dart
final firstName = 'John'.obs();
final lastName = 'Doe'.obs();

// This will update whenever firstName or lastName changes
String get fullName => '${firstName.value} ${lastName.value}';
```
## Reactive Types
### - Generic Reactive Value **Rx**
The base reactive type that can hold any value:
t
t
``` dart
// Basic types
final name = Rx<String>('Initial');
final count = Rx<int>(0);
final user = Rx<User?>(null);

// Using .obs() extension (preferred)
final name = 'Initial'.obs();
final count = 0.obs();
final user = Rx<User?>(null); // For nullable types without initial value
```
### - Reactive Boolean **RxBool**
Specialized reactive type for boolean values:
``` dart
final isLoading = false.obs();     // Creates RxBool
final isVisible = RxBool(true);    // Explicit constructor

// Boolean-specific methods
isLoading.toggle();                // Toggles true/false
print(isLoading.isTrue);           // true if value is true
print(isLoading.isFalse);          // true if value is false
```
### **RxList** - Reactive List
Reactive list that notifies on collection changes:
t
t
``` dart
final items = <String>[].obs();    // Creates RxList<String>
final numbers = RxList<int>();     // Empty reactive list

// Reactive operations
items.add('New Item');             // Triggers update
items.removeAt(0);                 // Triggers update
items.clear();                     // Triggers update
items.assignAll(['A', 'B', 'C']);  // Replace all items
```
### **RxMap<K, V>** - Reactive Map
Reactive map that notifies on key-value changes:
``` dart
final settings = <String, dynamic>{}.obs(); // Creates RxMap
final cache = RxMap<String, User>();        // Typed reactive map

// Reactive operations
settings['theme'] = 'dark';        // Triggers update
settings.remove('oldKey');         // Triggers update
settings.clear();                  // Triggers update
```
### **RxSet** - Reactive Set
Reactive set for unique collections:
t
t
``` dart
final tags = <String>{}.obs();     // Creates RxSet<String>
final uniqueIds = RxSet<int>();    // Empty reactive set

// Reactive operations
tags.add('flutter');               // Triggers update
tags.remove('dart');               // Triggers update
tags.addAll(['mobile', 'app']);    // Triggers update
```
## Creating Reactive Values
### **Using .obs() Extension** (Recommended)
The simplest way to create reactive values:
``` dart
// Primitive types
final name = 'John'.obs();         // Rx<String>
final age = 25.obs();              // Rx<int>
final height = 5.9.obs();          // Rx<double>
final isActive = true.obs();       // RxBool

// Collections
final items = <String>[].obs();    // RxList<String>
final settings = <String, int>{}.obs(); // RxMap<String, int>
final tags = <String>{}.obs();     // RxSet<String>

// Objects
final user = User('John', 25).obs(); // Rx<User>
```
### **Using Constructors**
For more control or nullable types:
``` dart
// Explicit constructors
final name = Rx<String>('John');
final optionalUser = Rx<User?>(null);
final items = RxList<String>();
final settings = RxMap<String, dynamic>();

// With initial values
final numbers = RxList<int>([1, 2, 3]);
final config = RxMap<String, String>({'theme': 'light'});
```
### **Late Initialization**
For values initialized later:
``` dart
class UserController extends ZenController {
  late final Rx<User> currentUser;
  late final RxList<String> notifications;
  
  @override
  void onInit() {
    super.onInit();
    currentUser = User.empty().obs();
    notifications = <String>[].obs();
  }
}
```
## Value Access Patterns
### **Reading Values**
``` dart
final count = 5.obs();

// Direct value access
int currentCount = count.value;

// Call operator (alternative)
int currentCount = count();

// In UI (within Obx or reactive context)
Text('${count.value}') // Automatically tracks changes
```
### **Writing Values**
``` dart
final count = 0.obs();

// Direct assignment
count.value = 10;

// Increment/decrement
count.value++;
count.value--;

// Using update function
count.update((val) => val + 5);
```
### **Conditional Updates**
``` dart
final status = 'inactive'.obs();

// Update only if condition is met
if (status.value != 'active') {
  status.value = 'active';
}

// Using update with condition
status.update((current) => 
  current == 'inactive' ? 'active' : current
);
```
## Reactive Collections
### **RxList Operations**
``` dart
final items = <String>[].obs();

// Adding items
items.add('New Item');
items.addAll(['Item 1', 'Item 2']);
items.insert(0, 'First Item');

// Removing items
items.remove('Item 1');
items.removeAt(0);
items.removeWhere((item) => item.startsWith('Old'));

// Replacing content
items.assignAll(['A', 'B', 'C']);
items.clear();

// Reactive transformations
final uppercaseItems = items.map((item) => item.toUpperCase()).toList();
```
### **RxMap Operations**
``` dart
final settings = <String, dynamic>{}.obs();

// Adding/updating
settings['theme'] = 'dark';
settings.addAll({'language': 'en', 'notifications': true});

// Removing
settings.remove('oldSetting');
settings.removeWhere((key, value) => value == null);

// Checking
if (settings.containsKey('theme')) {
  print('Theme: ${settings['theme']}');
}
```
### **RxSet Operations**
``` dart
final tags = <String>{}.obs();

// Adding
tags.add('flutter');
tags.addAll(['dart', 'mobile']);

// Removing
tags.remove('old-tag');
tags.removeWhere((tag) => tag.length < 3);

// Set operations
final otherTags = {'web', 'desktop'};
tags.addAll(otherTags);
final hasCommon = tags.intersection(otherTags).isNotEmpty;
```
## Computed Values
### **Simple Computed Properties**
``` dart
class UserController extends ZenController {
  final firstName = 'John'.obs();
  final lastName = 'Doe'.obs();
  
  // Computed value - automatically updates when dependencies change
  String get fullName => '${firstName.value} ${lastName.value}';
  
  // Complex computed value
  String get displayName {
    final first = firstName.value;
    final last = lastName.value;
    return first.isEmpty ? last : '$first $last';
  }
}
```
### **Using RxComputed** (If Available)
``` dart
class ShoppingController extends ZenController {
  final items = <CartItem>[].obs();
  final discount = 0.0.obs();
  
  // Computed total that updates when items or discount changes
  late final total = RxComputed<double>(() {
    final subtotal = items.fold(0.0, (sum, item) => sum + item.price);
    return subtotal * (1 - discount.value);
  });
}
```
### **Reactive Transformations**
``` dart
class TodoController extends ZenController {
  final todos = <Todo>[].obs();
  
  // Computed lists
  List<Todo> get completedTodos => 
    todos.where((todo) => todo.isCompleted).toList();
    
  List<Todo> get pendingTodos => 
    todos.where((todo) => !todo.isCompleted).toList();
    
  // Computed counts
  int get totalCount => todos.length;
  int get completedCount => completedTodos.length;
  double get completionPercentage => 
    totalCount == 0 ? 0 : completedCount / totalCount;
}
```
## Async Reactive Values
### **RxFuture** (If Available)
``` dart
class DataController extends ZenController {
  // Reactive future that tracks async operations
  late final userData = RxFuture<User>(() => api.fetchUser());
  
  Future<void> refreshUser() async {
    await userData.refresh(); // Triggers new fetch
  }
}

// In UI
Obx(() {
  return userData.when(
    loading: () => CircularProgressIndicator(),
    success: (user) => UserProfile(user),
    error: (error) => ErrorWidget(error),
  );
})
```
### **Manual Async Patterns**
``` dart
class ApiController extends ZenController {
  final isLoading = false.obs();
  final error = Rx<String?>(null);
  final data = Rx<List<Item>?>(null);
  
  Future<void> loadData() async {
    try {
      isLoading.value = true;
      error.value = null;
      
      final result = await api.fetchData();
      data.value = result;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
```
## Performance Optimization
### **Minimal Rebuilds**
``` dart
// Good: Specific reactive updates
Obx(() => Text('Count: ${counter.count.value}'))

// Avoid: Unnecessary reactive scope
Obx(() => Column(
  children: [
    Text('Static text'), // This doesn't need to be reactive
    Text('Count: ${counter.count.value}'), // Only this needs reactivity
  ],
))

// Better: Split reactive and static parts
Column(
  children: [
    Text('Static text'),
    Obx(() => Text('Count: ${counter.count.value}')),
  ],
)
```
### **Batched Updates**
``` dart
// Avoid multiple reactive updates
// Bad
firstName.value = 'John';
lastName.value = 'Doe';
age.value = 30;

// Better: Use update functions or batch changes
void updateUser(String first, String last, int userAge) {
  firstName.value = first;
  lastName.value = last;
  age.value = userAge;
  // All updates happen in same frame
}
```
### **Conditional Reactivity**
``` dart
class OptimizedController extends ZenController {
  final _internalCount = 0.obs();
  final isActive = true.obs();
  
  // Only expose reactivity when needed
  int get count => isActive.value ? _internalCount.value : 0;
  
  void increment() {
    if (isActive.value) {
      _internalCount.value++;
    }
  }
}
```
## Best Practices
### 1. **Use Descriptive Names**
``` dart
// Good
final isUserLoggedIn = false.obs();
final shoppingCartItems = <Product>[].obs();
final userPreferences = <String, dynamic>{}.obs();

// Avoid
final flag = false.obs();
final list = <dynamic>[].obs();
final data = <String, dynamic>{}.obs();
```
### 2. **Initialize with Sensible Defaults**
``` dart
class UserController extends ZenController {
  // Good: Clear initial states
  final isLoading = false.obs();
  final errorMessage = ''.obs();
  final users = <User>[].obs();
  final selectedUserId = Rx<String?>(null);
}
```
### 3. **Group Related State**
``` dart
class FormController extends ZenController {
  // Group form fields
  final formData = <String, dynamic>{
    'name': '',
    'email': '',
    'phone': '',
  }.obs();
  
  // Form validation state
  final formErrors = <String, String>{}.obs();
  final isFormValid = false.obs();
  
  void updateField(String field, dynamic value) {
    formData[field] = value;
    validateForm();
  }
}
```
### 4. **Use Computed Properties for Derived State**
``` dart
class ShoppingController extends ZenController {
  final cartItems = <CartItem>[].obs();
  
  // Computed properties instead of storing redundant state
  double get subtotal => cartItems.fold(0.0, (sum, item) => sum + item.price);
  double get tax => subtotal * 0.08;
  double get total => subtotal + tax;
  bool get hasItems => cartItems.isNotEmpty;
}
```
### 5. **Dispose Resources Properly**
``` dart
class ResourceController extends ZenController {
  final data = <String>[].obs();
  late StreamSubscription _subscription;
  
  @override
  void onInit() {
    super.onInit();
    _subscription = someStream.listen((value) {
      data.add(value);
    });
  }
  
  @override
  void onDispose() {
    _subscription.cancel();
    // Reactive values are automatically disposed by ZenController
    super.onDispose();
  }
}
```
## Advanced Usage
### **Custom Reactive Types**
``` dart
// Custom reactive wrapper for complex objects
class ReactiveUser {
  final _user = Rx<User?>(null);
  
  User? get user => _user.value;
  set user(User? value) => _user.value = value;
  
  // Expose specific properties reactively
  String get name => _user.value?.name ?? '';
  bool get isLoggedIn => _user.value != null;
  
  void updateName(String newName) {
    if (_user.value != null) {
      _user.value = _user.value!.copyWith(name: newName);
    }
  }
}
```
### **Reactive Transformations**
``` dart
class DataTransformController extends ZenController {
  final rawData = <Map<String, dynamic>>[].obs();
  
  // Transform raw data into typed objects
  List<User> get users => rawData
    .map((json) => User.fromJson(json))
    .toList();
    
  // Filter and sort reactively
  List<User> get activeUsers => users
    .where((user) => user.isActive)
    .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}
```
### **Reactive State Machines**
``` dart
enum LoadingState { initial, loading, success, error }

class StateMachineController extends ZenController {
  final _state = LoadingState.initial.obs();
  final _data = Rx<String?>(null);
  final _error = Rx<String?>(null);
  
  LoadingState get state => _state.value;
  String? get data => _data.value;
  String? get error => _error.value;
  
  bool get isLoading => _state.value == LoadingState.loading;
  bool get hasData => _state.value == LoadingState.success && _data.value != null;
  bool get hasError => _state.value == LoadingState.error;
  
  Future<void> loadData() async {
    _state.value = LoadingState.loading;
    _error.value = null;
    
    try {
      final result = await api.fetchData();
      _data.value = result;
      _state.value = LoadingState.success;
    } catch (e) {
      _error.value = e.toString();
      _state.value = LoadingState.error;
    }
  }
}
```
## Testing
### **Testing Reactive Values**
``` dart
void main() {
  group('Reactive Values', () {
    test('should update value correctly', () {
      final count = 0.obs();
      
      expect(count.value, 0);
      
      count.value = 5;
      expect(count.value, 5);
    });
    
    test('should notify listeners on change', () {
      final count = 0.obs();
      var notified = false;
      
      count.listen((value) {
        notified = true;
      });
      
      count.value = 1;
      expect(notified, true);
    });
  });
}
```
### **Testing Controllers with Reactive State**
``` dart
void main() {
  group('UserController', () {
    late UserController controller;
    
    setUp(() {
      controller = UserController();
    });
    
    tearDown(() {
      controller.dispose();
    });
    
    test('should load user data', () async {
      expect(controller.isLoading.value, false);
      expect(controller.user.value, null);
      
      await controller.loadUser('123');
      
      expect(controller.isLoading.value, false);
      expect(controller.user.value, isA<User>());
    });
  });
}
```
## Migration Guide
### **From setState**
``` dart
// Before: StatefulWidget with setState
class CounterWidget extends StatefulWidget {
  @override
  _CounterWidgetState createState() => _CounterWidgetState();
}

class _CounterWidgetState extends State<CounterWidget> {
  int count = 0;
  
  void increment() {
    setState(() {
      count++;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Text('$count');
  }
}

// After: Reactive with Zenify
class CounterController extends ZenController {
  final count = 0.obs();
  
  void increment() {
    count.value++;
  }
}

class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.find<CounterController>();
    return Obx(() => Text('${controller.count.value}'));
  }
}
```
### **From Provider**
``` dart
// Before: Provider + ChangeNotifier
class CounterNotifier extends ChangeNotifier {
  int _count = 0;
  int get count => _count;
  
  void increment() {
    _count++;
    notifyListeners();
  }
}

// Usage
Consumer<CounterNotifier>(
  builder: (context, counter, child) {
    return Text('${counter.count}');
  },
)

// After: Reactive Zenify
class CounterController extends ZenController {
  final count = 0.obs();
  
  void increment() {
    count.value++;
  }
}

// Usage
Obx(() => Text('${controller.count.value}'))
```
## Summary
Zenify's reactive system provides:
- **️ Performance**: Minimal rebuilds with automatic optimization
- **️ Simplicity**: Intuitive APIs with extension `.obs()`
- **️ Automatic Updates**: UI automatically reflects state changes
- **️ Rich Types**: Support for primitives, collections, and custom objects
- **️ Testable**: Easy to test reactive logic
- **️ Scalable**: Works from simple counters to complex applications

The reactive core is the foundation of Zenify's state management, providing the building blocks for effects, workers, and UI integration. Master these concepts to build efficient, maintainable Flutter applications.
