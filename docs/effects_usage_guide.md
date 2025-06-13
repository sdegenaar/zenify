# ZenEffects Usage Guide

## Overview

ZenEffect is a powerful tool for handling asynchronous operations in your Zenify controllers. It provides built-in state management for loading, error, and success states, making it easier to handle async operations in a clean and predictable way.

## Creating an Effect

Effects are typically created in your controller:

```dart
class UserController extends ZenController {
  // Create an effect with a meaningful name
  late final userProfileEffect = createEffect<UserProfile>(
    name: 'userProfile',
  );

  // You can also provide initial data if available
  late final settingsEffect = createEffect<Settings>(
    name: 'settings',
    initialData: Settings.defaults(),
  );
}
```

## Running an Effect

Use the `run()` method to execute an async operation while automatically managing the effect's state:

```dart
Future<void> loadUserProfile() async {
  try {
    await userProfileEffect.run(() async {
      final profile = await userService.getUserProfile();
      return profile;
    });
  } catch (e) {
    // Error will be handled by the effect's watch method
  }
}
```

## Observing Effect States

The recommended way to observe effect states is using the `watch` method in your controller's `onInit`:

```dart
@override
void onInit() {
  super.onInit();

  userProfileEffect.watch(
    this,
    onData: (profile) {
      if (profile != null) {
        // Update UI state based on profile data
        username.value = profile.name;
      }
    },
    onLoading: (loading) {
      isLoading.value = loading;
    },
    onError: (error) {
      if (error != null) {
        errorMessage.value = 'Failed to load profile';
      } else {
        errorMessage.value = '';
      }
    }
  );
}
```

## Building UI with Effects

Use the `ZenEffectBuilder` widget to respond to effect states in your UI:

```dart
ZenEffectBuilder<UserProfile>(
  effect: controller.userProfileEffect,
  onLoading: () => CircularProgressIndicator(),
  onSuccess: (profile) => UserProfileView(profile),
  onError: (error) => ErrorView(message: 'Could not load profile'),
)
```

## Best Practices

1. **Use meaningful names** for your effects to make debugging easier
2. **Handle errors properly** by catching exceptions from `run()` method
3. **Use the watch method** to react to effect state changes in your controller
4. **Reset effects when needed** using the `reset()` method
5. **Don't overuse effects** - use them for significant async operations, not for simple property changes

## Advanced Usage

### Manual State Control

You can manually control effect states if needed:

```dart
// Set loading state
userProfileEffect.loading();

// Set success state with data
userProfileEffect.success(userProfile);

// Set error state
userProfileEffect.setError('Failed to load profile');

// Reset effect to initial state
userProfileEffect.reset();
```

### Using Workers with Effects

If you need more granular control, you can use workers:

```dart
// Watch only data changes
ZenWorkers.effectData(userProfileEffect, (profile) {
  if (profile != null) {
    // Handle profile updates
  }
});

// Watch loading state changes
ZenWorkers.effectLoading(userProfileEffect, (loading) {
  showLoadingIndicator.value = loading;
});

// Watch error state changes
ZenWorkers.effectError(userProfileEffect, (error) {
  if (error != null) {
    showErrorDialog(error.toString());
  }
});
```

However, the `watch` method is generally preferred for most use cases as it's more concise and automatically cleans up listeners when the controller is disposed.
