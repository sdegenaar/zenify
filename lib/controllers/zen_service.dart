// lib/controllers/zen_service.dart
//
// ZenService — a permanent, long-lived singleton that inherits all of
// ZenController's memory safety (Rx tracking, worker tracking, lifecycle hooks).
//
// The only distinction from ZenController is that Zen.put() defaults
// ZenService instances to permanent=true.
//
// Usage:
// ```dart
// class ApiService extends ZenService {
//   late final baseUrl = obs('https://api.example.com');
//
//   @override
//   void onInit() {
//     super.onInit();
//     // one-time setup
//   }
// }
// ```

import 'zen_controller.dart';

/// A long-lived service singleton.
///
/// Extends [ZenController] and therefore inherits:
/// - Automatic disposal of tracked `Rx` objects via [obs]
/// - Worker and effect tracking
/// - `onInit`, `onReady`, `onClose`, and app lifecycle hooks
///
/// The only behavioural difference from [ZenController] is that
/// [Zen.put] registers a [ZenService] as **permanent** by default,
/// meaning it survives [Zen.reset] cleanup unless explicitly deleted.
abstract class ZenService extends ZenController {}
