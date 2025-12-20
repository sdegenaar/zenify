// lib/devtools/devtools.dart

/// Development tools and debugging utilities for Zenify
///
/// This module provides in-app debugging tools including:
/// - Inspector overlay for visualizing scope hierarchies
/// - Query cache viewer
/// - Dependency inspector
/// - Performance metrics
///
/// ## Safety
///
/// All devtools are designed to be safe for production builds:
/// - Automatically disabled in release mode by default
/// - Tree-shakes out when disabled (zero overhead)
/// - Multiple runtime guards prevent accidental activation
///
/// ## Usage
///
/// ```dart
/// import 'package:zenify/devtools/devtools.dart';
///
/// void main() {
///   runApp(
///     ZenInspectorOverlay(
///       child: MyApp(),  // ✅ Safe: uses kDebugMode by default
///     ),
///   );
/// }
/// ```
///
/// ## WARNING
///
/// Never enable devtools in production:
/// ```dart
/// ZenInspectorOverlay(
///   enabled: true,  // ❌ DANGEROUS in release builds!
///   child: MyApp(),
/// )
/// ```
library;

export 'inspector/zen_inspector_overlay.dart';
