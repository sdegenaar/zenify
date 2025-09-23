## 0.6.0

### 🚨 BREAKING CHANGES
- **Lifecycle Standardization**: Renamed lifecycle methods for consistency
    - `ZenController.onDispose()` → `ZenController.onClose()`
    - `ZenService.onDelete()` → `ZenService.onClose()`
- **API Consistency**: `ZenScope.put()` parameter `permanent` → `isPermanent`

### ✨ New Features
- **Automatic ZenService Disposal**: Services are automatically disposed when their scope is disposed (promotes proper scope design)
- **Enhanced ZenService Integration**: `ZenScope` now matches `Zen` API behavior for services
- **Smart Defaults**: ZenService instances default to permanent across all registration methods

### 🔧 Improvements
- Consistent lifecycle pattern: `onInit()` → `onClose()` → `dispose()`
- ZenService instances properly initialize from lazy factories
- Complete disposal coverage in all scope cleanup operations

### 🔄 Migration Guide
```
// Lifecycle methods
@override void onDispose() → @override void onClose()
@override void onDelete() → @override void onClose()

// Scope registration
scope.put(service, permanent: true) → scope.put(service, isPermanent: true)
```

### 📝 Internal Changes
- **Restructured ZenService disposal**: Added internal `dispose()` method that calls user's `onClose()`
- **Improved separation of concerns**: Clear distinction between user cleanup (`onClose()`) and framework disposal (`dispose()`)
- Updated all examples and documentation to use new lifecycle methods
- Enhanced error messages to reference correct method names

## 0.5.5
* **🆕 ZenService (long‑lived services)**
    * Adds `ZenService` base with `onInit` and `onClose` lifecycle hooks
    * Safe init: `isInitialized` set only after successful `onInit`
    * Guaranteed cleanup via `onDelete` → `onClose`

- **🧩 DI behavior and consistency**
    * `Zen.put(instance)`: `ZenService` defaults to `isPermanent = true` and initializes via lifecycle manager
    * `Zen.putLazy(factory)`: explicit permanence (default `false`); instance created on first `find()`
    * `Zen.putFactory(factory)`: unchanged; always creates new instances
    * `Zen.find()`: auto‑initializes `ZenService` on first access (covers lazy/scoped resolutions)

- **✅ Compatibility**
    * No changes to behavior `ZenController`
    * Works across scopes and modules with consistent lifecycle handling

- **🧪 Tests**
    * Added unit/integration tests for service init/disposal, lazy resolution, and error handling

- **📝 Docs**
    * Updated guidance on services vs controllers, permanence defaults, and initialization semantics

## 0.5.4

* **📱 Pub.dev Example Improvements**
    * Updated example application displayed on pub.dev package page
    * Cleaner code structure and improved readability for new users
    * Better demonstration of ZenView and reactive state patterns

## 0.5.3

* **🏆 Perfect pub.dev Package Score Achievement (160/160)**
    * Achieved maximum possible pub.dev score: 160/160 points
    * **Static Analysis (50/50)**: Fixed all linting issues and code formatting problems
    * **Documentation (10/10)**: Comprehensive README and API documentation maintained
    * **Example (30/30)**: Added complete example application demonstrating all features
    * **Maintenance (70/70)**: Up-to-date dependencies and Flutter compatibility
    * Fixed code formatting issues across the entire codebase using `dart format`
    * Added missing curly braces around single-line if statements for better code style
    * Improved documentation comments formatting to prevent HTML interpretation warnings
    * Enhanced code consistency by enforcing `curly_braces_in_flow_control_structures` rule
    * Updated analysis configuration to match pub.dev standards for optimal package quality
    * Ensured example application meets pub.dev requirements for discoverability and usability

## 0.5.2

* **📦 Package Metadata Improvements**
    * Updated topics to use `hierarchical-dependency-injection` for better discoverability
    * Improved SEO for dependency injection searches while highlighting hierarchical approach
    * Enhanced pub.dev searchability and positioning

## 0.5.1

* **🐛 Bug Fixes and Compatibility Improvements**
    * Fixed deprecated `RadioListTile` `groupValue` and `onChanged` parameters
    * Migrated to `RadioGroup` widget for radio button group management (Flutter 3.32.0+ compatibility)
    * Enhanced radio button implementation following Flutter's latest best practices

## 0.5.0

* **🚀 Official pub.dev Release**
    * Published Zenify to pub.dev as a stable pre-release package
    * Updated installation instructions to use `zenify: ^0.5.0` from pub.dev
    * Enhanced package description for better discoverability
    * Added comprehensive pub.dev metadata (topics, platforms, documentation links)
    * Prepared package for wider Flutter community adoption


## 0.4.1

* Documentation and Publishing Preparation
    * Polish README.md with improved formatting and comprehensive content
    * Enhance installation instructions and quick start guide
    * Add comprehensive feature highlights and comparison guidance
    * Refine documentation structure with "Coming Soon" sections for planned content
    * Update community links and support channels
    * Prepare package metadata for pub.dev publishing
* Code Quality and Performance Improvements
    * Add `const` keyword for durations and widgets across files for consistency
    * Apply `const` to widget declarations where applicable to reduce rebuilds
    * Fix minor typos in documentation paths from `docs/` to `doc/`
    * Improve code clarity and conformance with modern Dart guidelines
* Package Configuration Updates
    * Refine `pubspec.yaml` description for better pub.dev presentation
    * Update Flutter SDK constraint for compatibility
    * Adjust dependencies for optimal package setup


## 0.4.0

* Major Enhancement: Complete Module System and Route Management
    * **BREAKING**: Rename ZenModulePage to ZenRoute for clarity and better naming
    * Implement comprehensive hierarchical module system with ZenModule base class
    * Add ZenRoute widget for seamless module-based dependency injection
    * Implement stack-based scope tracking for reliable parent resolution
    * Add automatic scope cleanup and lifecycle management
    * Implement smart auto-dispose defaults based on scope hierarchy
    * Add comprehensive error handling with layout-aware loading/error states
    * Implement ZenScopeStackTracker for hierarchical scope inheritance
    * Add ZenScopeManager for centralized scope lifecycle management
    * Implement proper Zen.currentScope synchronization throughout navigation
    * Add comprehensive logging and debug support for scope operations
    * Implement robust parent scope resolution with multiple fallback strategies
    * Add comprehensive example applications (ecommerce, todo, showcase)
    * Restructure documentation with complete guides and improved examples
    * Add ZenConsumer widget for efficient dependency access with automatic caching
    * Implement production-ready module registration and cleanup patterns

## 0.3.0

* Major Enhancement: Production-Ready Reactive System
    * Complete reactive state management system with comprehensive error handling
    * Add RxResult<T> for robust error handling with success/failure patterns
    * Implement RxException with timestamp tracking and error context
    * Add RxComputed for automatic dependency tracking and computed values
    * Implement RxFuture for reactive async operations with state management
    * Add comprehensive error handling extensions for all reactive types
    * Implement circuit breaker pattern for resilient reactive operations
    * Add RxLogger with configurable error handling and context tracking
    * Implement extensive list extensions with safe operations and error handling
    * Add batch operations and bulk update support for collections
    * Implement retry logic with configurable delays and attempt limits
    * Add performance monitoring utilities and resource leak detection
    * Implement comprehensive test coverage for all reactive components
    * Add production-ready error configuration and logging systems
    * Implement automatic dependency cleanup and memory management
    * Add type-safe reactive operations with compile-time guarantees

## 0.2.0

* Major Enhancement: Widget System Expansion and Performance Optimization
    * Add ZenConsumer widget for efficient dependency access with automatic caching
    * Add comprehensive test suite for ZenConsumer widget functionality
    * Enhance widget system documentation with complete comparison table
    * Add examples demonstrating ZenConsumer for optional services and dependencies
    * Improve README with detailed widget selection guidelines and best practices
    * Add performance-optimized patterns for different UI scenarios
    * Update migration guide with widget system improvements

## 0.1.9

* Enhanced Testing and Logging Infrastructure
    * Add comprehensive memory leak detection test suite with tracking utilities
    * Implement resource lifecycle monitoring for controllers, scopes, and services
    * Add stress tests for rapid creation/disposal scenarios
    * Implement dependency resolution benchmark suite for performance monitoring
    * Add widget lifecycle tests with safe ZenView implementation patterns
    * Enhance error handling in test teardown processes
    * Add performance monitoring utilities with operations-per-second metrics
    * Improve test coverage for module registration and cleanup
    * Add hierarchical scope disposal verification tests
    * Implement batch operations benchmarking for large-scale dependency management

## 0.1.8

* Major Enhancement: ZenView Integration and Widget System
    * Add ZenView base class for automatic controller management in pages
    * Implement direct controller access pattern (controller.property)
    * Add ZenViewRegistry for controller lifecycle management
    * Introduce context extensions for nested widget controller access
    * Replace manual Zen.find() pattern with automatic binding
    * Add comprehensive ZenView examples and patterns
    * Improve error handling with clear controller availability messages
    * Update documentation with ZenView best practices
    * Add support for tagged controllers in ZenView
    * Enhance type safety with automatic controller resolution

## 0.1.7

* Complete Phase 4: API Consistency and Reference System Improvements
    * Rename `lookup` to `find` for more intuitive API
    * Add `findOrNull` method for non-throwing dependency lookup
    * Enhance reference system with `EagerRef` and `LazyRef` implementations
    * Improve error handling in ZenView for better debugging
    * Refine scope management in widget integration
    * Update examples to use new API methods
    * Fix dependency resolution in hierarchical scopes

## 0.1.6

* Complete Phase 3: Logging and Testing Improvements
    * Replace print statements with structured ZenLogger system
    * Add proper log levels (debug, warning, error) for better debugging
    * Add comprehensive tests for dependency injection functionality
    * Implement test helpers for isolated scope testing
    * Add integration tests for scoped dependencies
    * Improve error handling with descriptive messages

## 0.1.5

* Complete Phase 2: Dependency Management Improvements
    * Implement hierarchical scope system for nested controller access
    * Add circular dependency detection to prevent deadlocks
    * Create module/binding system for organized dependency registration
    * Enhance controller discovery with improved scoping
    * Add lazy initialization support for dependencies
    * Improve error reporting for dependency resolution issues

## 0.1.4

* Complete Phase 1: Enhanced Type Safety
    * Add generic type constraints to all collections (RxList<E>, RxMap<K,V>, RxSet<E>)
    * Implement typed provider references with ControllerRef<T>
    * Add compile-time type checking for controller dependencies
    * Ensure type safety throughout reactive system and DI container

## 0.1.3

* Add ZenEffect for handling async operations with loading states
* Improve worker compatibility with proper RxNotifier types
* Fix type compatibility issues between RxInt and RxNotifier
* Add examples demonstrating async effects and reactive data flows
* Enhance documentation for state bridging patterns

## 0.1.2

* Update minimum Dart SDK to 2.19.0
* Fix deprecated IndexError usage with IndexError.withLength
* Improve logging system with developer.log instead of print statements
* Fix collection implementations for better type safety
* Add missing implementations in RxList, RxMap, and RxSet classes

## 0.1.1

* Initial release
* Core state management features
* Reactive state with Rx objects
* Controller lifecycle management
* Route-based controller disposal