# Hierarchical Scopes Example

This example demonstrates how to use ZenState's hierarchical scopes with `ZenBuilder` and `ZenControllerScope`.

## Key Features Demonstrated

1. **Hierarchical Scopes**:
    - Root scope for the entire app
    - Login scope for the login page
    - Profile scope for the profile page

2. **Module System**:
    - NetworkModule, AuthModule, and ProfileModule with dependencies
    - Proper module registration in specific scopes

3. **Controller Management**:
    - Using `ZenControllerScope` for lifecycle management
    - Using `ZenBuilder` for reactive UI updates

4. **Scope-Based Resolution**:
    - Controllers and services properly resolved through scopes
    - Parent-child relationship for dependency inheritance

## Running the Example
