``` markdown
# Zenify Example

A minimal counter app demonstrating the basic usage of Zenify state management.

## What This Example Shows

- ✅ **ZenView** - Base class for pages with automatic controller lifecycle
- ✅ **ZenController** - State management with reactive variables
- ✅ **Observable State** - Using `.obs()` for reactive values
- ✅ **Reactive Widgets** - `Obx()` for automatic UI updates
- ✅ **Controller Access** - Direct `controller` property access in ZenView

## Running the Example

```bash
cd example
flutter run
```
```
## More Examples
This is the simplest possible Zenify example. For more advanced patterns, explore:
- **[Counter App](counter/)** - Full-featured counter with proper app structure
- **[Todo App](todo/)** - CRUD operations with effects and state management
- **[E-commerce App](ecommerce/)** - Real-world patterns and modules
- **[Showcase App](zenify_showcase/)** - All Zenify features demonstrated

## Code Highlights
### 1. Controller Definition
``` dart
class CounterController extends ZenController {
  final count = 0.obs();
  
  void increment() => count.value++;
  void decrement() => count.value--;
}
```
### 2. ZenView Usage
``` dart
class CounterPage extends ZenView<CounterController> {
  @override
  CounterController Function()? get createController => () => CounterController();

  @override
  Widget build(BuildContext context) {
    // Direct access to controller without Zen.find()
    return Obx(() => Text('${controller.count.value}'));
  }
}
```
## Key Benefits Demonstrated
1. **Zero Boilerplate** - No manual disposal or lifecycle management needed
2. **Automatic Cleanup** - Controller disposed when page is removed
3. **Type Safety** - Full compile-time type checking
4. **Reactive Updates** - UI automatically updates when state changes
5. **Simple API** - Intuitive patterns for common use cases

## Next Steps
- **Try it yourself** - Modify the counter logic or add new features
- **Explore advanced examples** - Check out the [other examples](./) above
- **Learn more** - Visit the [main documentation](../README.md)

This example provides the foundation for understanding Zenify's core concepts. Once you're comfortable with these basics, explore the other examples to see more advanced features like modules, effects, and hierarchical scopes.
