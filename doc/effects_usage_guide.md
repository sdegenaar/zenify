# ZenEffects Usage Guide

## Overview

ZenEffect is a powerful tool for handling asynchronous operations in your Zenify controllers. It provides built-in state management for loading, error, and success states, making it easier to handle async operations in a clean and predictable way.

## Table of Contents
- [Creating an Effect](#creating-an-effect)
- [Running an Effect](#running-an-effect)
- [Observing Effect States](#observing-effect-states)
- [Building UI with Effects](#building-ui-with-effects)
- [Effect Properties](#effect-properties)
- [Manual State Control](#manual-state-control)
- [Advanced Usage](#advanced-usage)
- [Best Practices](#best-practices)
- [Example App](#example-app)

## Creating an Effect

Effects are typically created in your controller using the `createEffect` function:

```dart
class UserController extends ZenController {
  // Create an effect with a meaningful name
  late final userProfileEffect = createEffect<UserProfile>(
    name: 'userProfile',
  );

  // Effects for different data types
  late final settingsEffect = createEffect<Settings>(
    name: 'settings',
  );

  // Nullable types are supported
  late final optionalDataEffect = createEffect<String?>(
    name: 'optionalData',
  );
}
```
```
## Running an Effect
Use the method to execute an async operation while automatically managing the effect's state: `run()`
``` dart
Future<void> loadUserProfile() async {
  try {
    await userProfileEffect.run(() async {
      final profile = await userService.getUserProfile();
      return profile;
    });
  } catch (e) {
    // Error is automatically captured by the effect
    // Additional error handling can be done here if needed
    print('Profile loading failed: $e');
  }
}

// The run method automatically:
// 1. Sets loading state to true
// 2. Clears any previous errors
// 3. Executes your async operation
// 4. Sets success state with the result
// 5. Or sets error state if an exception occurs
```
## Observing Effect States
The recommended way to observe effect states is using the `watch` method in your controller's `onInit`:
``` dart
@override
void onInit() {
  super.onInit();

  // Watch all effect state changes
  userProfileEffect.watch(
    this,
    onData: (profile) {
      if (profile != null) {
        // Update UI state based on profile data
        username.value = profile.name;
        email.value = profile.email;
      }
    },
    onLoading: (loading) {
      isLoading.value = loading;
    },
    onError: (error) {
      if (error != null) {
        errorMessage.value = 'Failed to load profile: ${error.toString()}';
      } else {
        errorMessage.value = '';
      }
    }
  );

  // Watch specific aspects only
  settingsEffect.watchData(this, (settings) {
    if (settings != null) {
      updateUIWithSettings(settings);
    }
  });

  settingsEffect.watchLoading(this, (loading) {
    showSpinner.value = loading;
  });

  settingsEffect.watchError(this, (error) {
    if (error != null) {
      showErrorDialog(error.toString());
    }
  });
}
```
## Building UI with Effects
Use the `ZenEffectBuilder` widget to respond to effect states in your UI:
``` dart
ZenEffectBuilder<UserProfile>(
  effect: controller.userProfileEffect,
  onInitial: () => const Text('Ready to load profile'),
  onLoading: () => const CircularProgressIndicator(),
  onSuccess: (profile) => UserProfileView(profile),
  onError: (error) => ErrorView(
    message: 'Could not load profile',
    error: error,
    onRetry: () => controller.loadUserProfile(),
  ),
)
```
### ZenEffectBuilder with Custom Wrapper
``` dart
ZenEffectBuilder<List<String>>(
  effect: controller.dataEffect,
  onInitial: () => const Text('No data loaded'),
  onLoading: () => const CircularProgressIndicator(),
  onSuccess: (data) => ListView.builder(
    itemCount: data.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(data[index]),
    ),
  ),
  onError: (error) => Text('Error: $error'),
  builder: (context, child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  ),
)
```
## Effect Properties
ZenEffect provides several reactive properties you can observe:
``` dart
class MyController extends ZenController {
  late final dataEffect = createEffect<String>(name: 'data');

  void checkEffectState() {
    // Check current data
    String? currentData = dataEffect.data.value;
    
    // Check if loading
    bool isLoading = dataEffect.isLoading.value;
    
    // Check for errors
    Object? error = dataEffect.error.value;
    
    // Check if data was ever set (even if null)
    bool hasBeenSet = dataEffect.dataWasSet.value;
    
    // Convenience getter
    bool hasData = dataEffect.hasData;
    
    // Check if effect is disposed
    bool isDisposed = dataEffect.isDisposed;
  }
}
```
## Manual State Control
You can manually control effect states when needed:
``` dart
class DataController extends ZenController {
  late final dataEffect = createEffect<List<Item>>(name: 'items');

  void manualStateManagement() {
    // Set loading state manually
    dataEffect.loading();

    // Set success state with data
    dataEffect.success(items);

    // Set error state
    dataEffect.setError('Network connection failed');

    // Reset to initial state
    dataEffect.reset();

    // Clear only the error
    dataEffect.clearError();

    // Clear only the data
    dataEffect.clearData();
  }

  // Example: Progressive data loading
  Future<void> loadDataWithProgress() async {
    dataEffect.loading();
    
    try {
      // Load first batch
      final batch1 = await api.loadBatch(1);
      dataEffect.success(batch1);
      
      // Load second batch and append
      final batch2 = await api.loadBatch(2);
      final allData = [...batch1, ...batch2];
      dataEffect.success(allData);
      
    } catch (e) {
      dataEffect.setError(e);
    }
  }
}
```
## Advanced Usage
### Effect State Transitions
Effects follow this state priority order:
1. **Loading**: Takes precedence over all other states
2. **Error**: Takes precedence over success and initial
3. **Success**: When data is available (including null data that was explicitly set)
4. **Initial**: Default state when no data has been set
``` dart
// Understanding state transitions
effect.reset();           // Initial state
effect.loading();         // Loading state
effect.success(data);     // Success state
effect.setError(error);   // Error state (overrides success)
effect.clearError();      // Back to success state (if data exists)
effect.reset();           // Back to initial state
```
### Handling Nullable Data
``` dart
class NullableDataController extends ZenController {
  late final nullableEffect = createEffect<String?>(name: 'nullable');

  Future<void> loadOptionalData() async {
    await nullableEffect.run(() async {
      // This can return null and it's a valid success state
      return await api.getOptionalData();
    });
  }

  @override
  void onInit() {
    super.onInit();
    
    nullableEffect.watch(
      this,
      onData: (data) {
        // data can be null, but this callback will still be called
        // Use dataWasSet to distinguish between "no data" and "null data"
        if (nullableEffect.hasData) {
          print('Data was set: $data (can be null)');
        }
      },
    );
  }
}
```
### Multiple Concurrent Effects
``` dart
class MultiEffectController extends ZenController {
  late final effect1 = createEffect<String>(name: 'effect1');
  late final effect2 = createEffect<String>(name: 'effect2');
  late final effect3 = createEffect<String>(name: 'effect3');

  Future<void> runAllConcurrently() async {
    // Run multiple effects at the same time
    await Future.wait([
      effect1.run(() => api.fetchData1()),
      effect2.run(() => api.fetchData2()),
      effect3.run(() => api.fetchData3()),
    ]);
  }

  Future<void> runSequentially() async {
    // Run effects one after another
    await effect1.run(() => api.fetchData1());
    await effect2.run(() => api.fetchData2());
    await effect3.run(() => api.fetchData3());
  }

  void resetAllEffects() {
    effect1.reset();
    effect2.reset();
    effect3.reset();
  }
}
```
### Effect Lifecycle Management
``` dart
class LifecycleController extends ZenController {
  late final dataEffect = createEffect<String>(name: 'data');

  @override
  void onInit() {
    super.onInit();
    
    // Set up effect watching
    dataEffect.watch(this, 
      onData: (data) => handleData(data),
      onError: (error) => handleError(error),
    );
  }

  @override
  void onDispose() {
    // Effects are automatically disposed when the controller is disposed
    // But you can manually dispose them if needed
    if (!dataEffect.isDisposed) {
      dataEffect.dispose();
    }
    
    super.onDispose();
  }
}
```
## Best Practices
### 1. Use Meaningful Names
``` dart
// Good
late final userProfileEffect = createEffect<UserProfile>(name: 'userProfile');
late final weatherDataEffect = createEffect<Weather>(name: 'weatherData');

// Avoid
late final effect1 = createEffect<String>(name: 'effect1');
late final dataEffect = createEffect<dynamic>(name: 'data');
```
### 2. Handle Errors Appropriately
``` dart
Future<void> loadData() async {
  try {
    await dataEffect.run(() async {
      return await api.fetchData();
    });
  } catch (e) {
    // Effect automatically captures the error
    // Add additional logging or recovery logic here
    logger.error('Data loading failed', e);
    
    // Optionally show user-friendly message
    showUserMessage('Failed to load data. Please try again.');
  }
}
```
### 3. Use the watch Method for Reactive Updates
``` dart
@override
void onInit() {
  super.onInit();
  
  // Preferred: Use watch for reactive state management
  userEffect.watch(this,
    onData: (user) => updateUIState(user),
    onLoading: (loading) => showLoading(loading),
    onError: (error) => showError(error),
  );
}
```
### 4. Reset Effects When Appropriate
``` dart
void logout() {
  // Clear user-specific effects on logout
  userProfileEffect.reset();
  settingsEffect.reset();
  notificationsEffect.reset();
}

void refreshData() {
  // Reset before reloading to show loading state
  dataEffect.reset();
  loadData();
}
```
### 5. Don't Overuse Effects
``` dart
class CounterController extends ZenController {
  // Good: Simple reactive value
  final count = 0.obs();
  
  // Avoid: Effect for simple synchronous operations
  // late final countEffect = createEffect<int>(name: 'count');
  
  void increment() {
    count.value++; // Simple reactive update
  }
  
  // Good: Effect for async operations
  late final saveEffect = createEffect<bool>(name: 'save');
  
  Future<void> saveToServer() async {
    await saveEffect.run(() async {
      return await api.saveData(count.value);
    });
  }
}
```
## Example App
See the [zenify_showcase](../examples/zenify_showcase) for a complete demonstration of ZenEffects in action:
``` bash
# Run the example
cd examples/zenify_showcase
flutter run
```
The example app demonstrates:
- Basic effect usage with success and error states
- Data fetching patterns
- Multiple concurrent effects
- State monitoring and debugging
- Real-world UI integration patterns

This provides hands-on experience with all the concepts covered in this guide.
