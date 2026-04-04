// Example demonstrating the new exception system
// ignore_for_file: avoid_print

import 'package:zenify/zenify.dart';

void main() {
  // ============================================================================
  // COMPACT FORMAT (Default)
  // ============================================================================

  print('=== COMPACT FORMAT (Default) ===\n');

  try {
    throw ZenDependencyNotFoundException(
      typeName: 'UserService',
      scopeName: 'RootScope',
    );
  } catch (e) {
    print(e);
    print('');
  }

  try {
    throw ZenControllerNotFoundException(typeName: 'LoginController');
  } catch (e) {
    print(e);
    print('');
  }

  try {
    throw const ZenOfflineException();
  } catch (e) {
    print(e);
    print('');
  }

  // ============================================================================
  // VERBOSE FORMAT (Opt-in)
  // ============================================================================

  print('\n=== VERBOSE FORMAT (Opt-in) ===\n');

  // Enable verbose errors
  ZenConfig.verboseErrors = true;

  try {
    throw ZenDependencyNotFoundException(
      typeName: 'UserService',
      scopeName: 'RootScope',
      tag: 'authenticated',
    );
  } catch (e) {
    print(e);
    print('');
  }

  try {
    throw ZenQueryException(
      'Failed to fetch user data',
      context: {'QueryKey': 'user:123'},
      suggestion: 'Check your network connection and retry',
      cause: Exception('Network timeout'),
    );
  } catch (e) {
    print(e);
    print('');
  }

  // ============================================================================
  // LOGGER INTEGRATION
  // ============================================================================

  print('\n=== LOGGER INTEGRATION ===\n');

  // Reset to compact for logger demo
  ZenConfig.verboseErrors = false;
  ZenConfig.configure(level: ZenLogLevel.error);

  try {
    throw ZenMutationException(
      'Failed to create post',
      context: {'MutationKey': 'createPost'},
      suggestion: 'Verify the post data is valid',
    );
  } catch (e) {
    // Log using ZenLogger
    ZenLogger.logException(e);
  }
}
