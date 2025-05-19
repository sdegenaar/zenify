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