// lib/devtools/devtools.dart

/// Service extensions for DevTools integration
///
/// This module provides service extensions that allow the DevTools extension
/// to query the running app for scope hierarchy, dependencies, and other debug information.
///
/// ## Usage
///
/// Register service extensions in your app's main() function:
///
/// ```dart
/// import 'package:zenify/devtools/devtools.dart';
///
/// void main() {
///   ZenServiceExtensions.registerExtensions();
///   runApp(MyApp());
/// }
/// ```
///
/// ## DevTools Extension
///
/// To use the visual DevTools extension, add it as a dev dependency:
///
/// ```yaml
/// dev_dependencies:
///   zenify_devtools_extension: ^1.0.0
/// ```
library;

export 'service_extensions.dart' show ZenServiceExtensions;
