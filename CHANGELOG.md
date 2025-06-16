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