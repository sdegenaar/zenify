# GetX to Zenify Migration Guide

## 🚀 Quick Migration

### Automated Migration (Recommended)

Use our migration script to automatically convert most GetX code (experimental/testing:

```bash
# Preview changes (dry run)
dart tools/migrate_from_getx.dart /path/to/your/project --dry-run

# Apply changes
dart tools/migrate_from_getx.dart /path/to/your/project
```

The script will:
- ✅ Convert 70-80% of GetX code automatically
- ⚠️ Flag files that need manual review
- 📊 Generate a detailed migration report

---

## 📋 Manual Migration Reference

### 1. Dependencies

**pubspec.yaml:**
```yaml
# Remove
dependencies:
  get: ^4.6.5

# Add
dependencies:
  zenify: ^1.6.4
```

---

### 2. Imports

```dart
// Before
import 'package:get/get.dart';

// After
import 'package:zenify/zenify.dart';
```

---

### 3. Controllers

```dart
// Before
class MyController extends GetxController {
  final count = 0.obs;
  void increment() => count.value++;
}

// After
class MyController extends ZenController {
  final count = 0.obs();  // Note: .obs() with parentheses
  void increment() => count.value++;
}
```

---

### 4. Dependency Injection

```dart
// Before
Get.put(MyController());
final controller = Get.find<MyController>();
Get.delete<MyController>();

// After
Zen.put(MyController());
final controller = Zen.find<MyController>();
// or Zen.get<MyController>() - new in v1.6.3!
Zen.delete<MyController>();
// or Zen.remove<MyController>() - new in v1.6.3!
```

---

### 5. Reactive Widgets

```dart
// Before
Obx(() => Text('${controller.count}'))

// After - Both work!
Obx(() => Text('${controller.count}'))
ZenObserver(() => Text('${controller.count}'))  // New in v1.6.4
```

---

### 6. Builder Widgets

```dart
// Before
GetBuilder<MyController>(
  builder: (controller) => Text('${controller.count}'),
)

// After
ZenBuilder<MyController>(
  builder: (controller) => Text('${controller.count}'),
)
```

---

### 7. View Widgets

```dart
// Before
class MyPage extends GetView<MyController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.count}');
  }
}

// After
class MyPage extends ZenView<MyController> {
  @override
  Widget build(BuildContext context) {
    return Text('${controller.count}');
  }
}
```

---

## ⚠️ Manual Migrations Required

### Navigation

GetX navigation needs manual conversion to Flutter's Navigator:

```dart
// Before
Get.to(NextPage());
Get.back();
Get.off(NextPage());
Get.offAll(HomePage());

// After
Navigator.push(context, MaterialPageRoute(builder: (_) => NextPage()));
Navigator.pop(context);
Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NextPage()));
Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => HomePage()), (_) => false);
```

**Or use Zenify's routing:**
```dart
ZenRoute(
  path: '/next',
  builder: () => NextPage(),
)
```

---

### Bindings → Modules

```dart
// Before
class MyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MyController());
    Get.put(MyService());
  }
}

// After
class MyModule extends ZenModule {
  @override
  String get name => 'MyModule';
  
  @override
  void register(ZenScope scope) {
    scope.putLazy(() => MyController());
    scope.put(MyService());
  }
}
```

---

### GetMaterialApp → MaterialApp

```dart
// Before
GetMaterialApp(
  home: HomePage(),
  getPages: [...],
)

// After
MaterialApp(
  home: HomePage(),
  // Use Flutter's routing or ZenRoute
)
```

---

## 🎯 Key Differences

| Feature | GetX | Zenify |
|---------|------|--------|
| **Reactive** | `.obs` | `.obs()` (with parentheses) |
| **DI** | `Get.find()` | `Zen.find()` or `Zen.get()` |
| **Widget** | `Obx()` | `Obx()` or `ZenObserver()` |
| **Routing** | Built-in | Use Flutter Navigator or ZenRoute |
| **Scoping** | Global | Hierarchical scopes |

---

## ✅ Migration Checklist

- [ ] Run migration script
- [ ] Update pubspec.yaml
- [ ] Run `flutter pub get`
- [ ] Fix `.obs` → `.obs()` (add parentheses)
- [ ] Migrate navigation to Flutter Navigator
- [ ] Convert Bindings to ZenModule
- [ ] Replace GetMaterialApp with MaterialApp
- [ ] Test all features
- [ ] Remove GetX dependency

---

## 💡 Zenify Advantages

**What you gain:**
- ✅ **Hierarchical Scoping** - Better dependency management
- ✅ **Query System** - TanStack Query-like data fetching
- ✅ **Offline Support** - Built-in persistence and sync
- ✅ **Better Testing** - Scoped dependencies are easier to test
- ✅ **Cleaner API** - Consistent naming across all features

---

## 🆘 Need Help?

- 📖 [Full Documentation](../README.md)
- 💬 [GitHub Issues](https://github.com/sdegenaar/zenify/issues)
- 📧 Contact: [your-email]

**Welcome to Zenify!** 🎉
