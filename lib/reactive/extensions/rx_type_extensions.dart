
// lib/reactive/extensions/rx_type_extensions.dart
import '../core/rx_value.dart';
import '../core/rx_tracking.dart';
import '../core/rx_error_handling.dart';
import '../utils/rx_logger.dart';

// ============================================================================
// NUMERIC EXTENSIONS
// ============================================================================

/// Extensions for reactive integers
extension RxIntExtensions on Rx<int> {
  // ============================================================================
  // TRY* METHODS (Explicit error handling)
  // ============================================================================

  /// Increment with error handling
  RxResult<void> tryIncrement([int step = 1]) {
    return RxResult.tryExecute(() {
      value = value + step;
    }, 'increment by $step');
  }

  /// Decrement with error handling
  RxResult<void> tryDecrement([int step = 1]) {
    return RxResult.tryExecute(() {
      value = value - step;
    }, 'decrement by $step');
  }

  /// Multiply with error handling
  RxResult<void> tryMultiply(num factor) {
    return RxResult.tryExecute(() {
      value = (value * factor).round();
    }, 'multiply by $factor');
  }

  /// Divide with error handling
  RxResult<void> tryDivide(num divisor) {
    return RxResult.tryExecute(() {
      if (divisor == 0) {
        throw const RxException('Division by zero');
      }
      value = (value / divisor).round();
    }, 'divide by $divisor');
  }

  /// Modulo with error handling
  RxResult<void> tryModulo(int divisor) {
    return RxResult.tryExecute(() {
      if (divisor == 0) {
        throw const RxException('Modulo by zero');
      }
      value = value % divisor;
    }, 'modulo by $divisor');
  }

  /// Power with error handling
  RxResult<void> tryPower(int exponent) {
    return RxResult.tryExecute(() {
      if (exponent < 0) {
        throw const RxException('Negative exponent not supported for integers');
      }
      var result = 1;
      for (var i = 0; i < exponent; i++) {
        result *= value;
      }
      value = result;
    }, 'raise to power $exponent');
  }

  // ============================================================================
  // CONVENIENCE METHODS (call try* versions internally)
  // ============================================================================

  /// Increment (convenience method)
  void increment([int step = 1]) {
    final result = tryIncrement(step);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Int');
    }
  }

  /// Decrement (convenience method)
  void decrement([int step = 1]) {
    final result = tryDecrement(step);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Int');
    }
  }

  /// Multiply (convenience method)
  void multiply(num factor) {
    final result = tryMultiply(factor);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Int');
    }
  }

  /// Divide (convenience method)
  void divide(num divisor) {
    final result = tryDivide(divisor);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Int');
    }
  }

  /// Modulo (convenience method)
  void modulo(int divisor) {
    final result = tryModulo(divisor);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Int');
    }
  }

  /// Power (convenience method)
  void power(int exponent) {
    final result = tryPower(exponent);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Int');
    }
  }

  // ============================================================================
  // SAFE GETTERS (with tracking)
  // ============================================================================

  /// Check if number is even
  bool get isEven {
    RxTracking.track(this);
    return value.isEven;
  }

  /// Check if number is odd
  bool get isOdd {
    RxTracking.track(this);
    return value.isOdd;
  }

  /// Check if number is negative
  bool get isNegative {
    RxTracking.track(this);
    return value.isNegative;
  }

  /// Get absolute value
  int get abs {
    RxTracking.track(this);
    return value.abs();
  }

  /// Get sign (-1, 0, or 1)
  int get sign {
    RxTracking.track(this);
    return value.sign;
  }
}

/// Extensions for reactive doubles
extension RxDoubleExtensions on Rx<double> {
  // ============================================================================
  // TRY* METHODS (Explicit error handling)
  // ============================================================================

  /// Increment with error handling
  RxResult<void> tryIncrement([double step = 1.0]) {
    return RxResult.tryExecute(() {
      value = value + step;
    }, 'increment by $step');
  }

  /// Decrement with error handling
  RxResult<void> tryDecrement([double step = 1.0]) {
    return RxResult.tryExecute(() {
      value = value - step;
    }, 'decrement by $step');
  }

  /// Multiply with error handling
  RxResult<void> tryMultiply(num factor) {
    return RxResult.tryExecute(() {
      value = value * factor;
    }, 'multiply by $factor');
  }

  /// Divide with error handling
  RxResult<void> tryDivide(num divisor) {
    return RxResult.tryExecute(() {
      if (divisor == 0) {
        throw const RxException('Division by zero');
      }
      value = value / divisor;
    }, 'divide by $divisor');
  }

  // ============================================================================
  // CONVENIENCE METHODS (call try* versions internally)
  // ============================================================================

  /// Increment (convenience method)
  void increment([double step = 1.0]) {
    final result = tryIncrement(step);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Double');
    }
  }

  /// Decrement (convenience method)
  void decrement([double step = 1.0]) {
    final result = tryDecrement(step);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Double');
    }
  }

  /// Multiply (convenience method)
  void multiply(num factor) {
    final result = tryMultiply(factor);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Double');
    }
  }

  /// Divide (convenience method)
  void divide(num divisor) {
    final result = tryDivide(divisor);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Double');
    }
  }

  // ============================================================================
  // SAFE GETTERS (with tracking)
  // ============================================================================

  /// Check if number is negative
  bool get isNegative {
    RxTracking.track(this);
    return value.isNegative;
  }

  /// Get absolute value
  double get abs {
    RxTracking.track(this);
    return value.abs();
  }

  /// Get sign (-1.0, 0.0, or 1.0) - NOTE: double.sign returns double!
  double get sign {
    RxTracking.track(this);
    return value.sign;
  }

  /// Check if number is finite
  bool get isFinite {
    RxTracking.track(this);
    return value.isFinite;
  }

  /// Check if number is infinite
  bool get isInfinite {
    RxTracking.track(this);
    return value.isInfinite;
  }

  /// Check if number is NaN
  bool get isNaN {
    RxTracking.track(this);
    return value.isNaN;
  }

  /// Round to nearest integer
  void round() {
    value = value.roundToDouble();
  }

  /// Floor to integer
  void floor() {
    value = value.floorToDouble();
  }

  /// Ceiling to integer
  void ceil() {
    value = value.ceilToDouble();
  }

  /// Truncate to integer
  void truncate() {
    value = value.truncateToDouble();
  }
}

// ============================================================================
// BOOLEAN EXTENSIONS
// ============================================================================

/// Extensions for reactive booleans
extension RxBoolExtensions on Rx<bool> {
  // ============================================================================
  // TRY* METHODS (Explicit error handling)
  // ============================================================================

  /// Toggle with error handling
  RxResult<void> tryToggle() {
    return RxResult.tryExecute(() {
      value = !value;
    }, 'toggle boolean');
  }

  /// Set to true with error handling
  RxResult<void> trySetTrue() {
    return RxResult.tryExecute(() {
      value = true;
    }, 'set to true');
  }

  /// Set to false with error handling
  RxResult<void> trySetFalse() {
    return RxResult.tryExecute(() {
      value = false;
    }, 'set to false');
  }

  // ============================================================================
  // CONVENIENCE METHODS (call try* versions internally)
  // ============================================================================

  /// Toggle (convenience method)
  void toggle() {
    final result = tryToggle();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Bool');
    }
  }

  /// Set to true (convenience method)
  void setTrue() {
    final result = trySetTrue();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Bool');
    }
  }

  /// Set to false (convenience method)
  void setFalse() {
    final result = trySetFalse();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'Bool');
    }
  }
}

// ============================================================================
// STRING EXTENSIONS
// ============================================================================

/// Extensions for reactive strings
extension RxStringExtensions on Rx<String> {
  // ============================================================================
  // TRY* METHODS (Explicit error handling)
  // ============================================================================

  /// Append text with error handling
  RxResult<void> tryAppend(String text) {
    return RxResult.tryExecute(() {
      value = value + text;
    }, 'append text');
  }

  /// Prepend text with error handling
  RxResult<void> tryPrepend(String text) {
    return RxResult.tryExecute(() {
      value = text + value;
    }, 'prepend text');
  }

  /// Clear with error handling
  RxResult<void> tryClear() {
    return RxResult.tryExecute(() {
      value = '';
    }, 'clear string');
  }

  /// Convert to uppercase with error handling
  RxResult<void> tryToUpperCase() {
    return RxResult.tryExecute(() {
      value = value.toUpperCase();
    }, 'convert to uppercase');
  }

  /// Convert to lowercase with error handling
  RxResult<void> tryToLowerCase() {
    return RxResult.tryExecute(() {
      value = value.toLowerCase();
    }, 'convert to lowercase');
  }

  /// Trim with error handling
  RxResult<void> tryTrim() {
    return RxResult.tryExecute(() {
      value = value.trim();
    }, 'trim string');
  }

  /// Replace with error handling
  RxResult<void> tryReplace(Pattern from, String replace) {
    return RxResult.tryExecute(() {
      value = value.replaceAll(from, replace);
    }, 'replace in string');
  }

  // ============================================================================
  // CONVENIENCE METHODS (call try* versions internally)
  // ============================================================================

  /// Append text (convenience method)
  void append(String text) {
    final result = tryAppend(text);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'String');
    }
  }

  /// Prepend text (convenience method)
  void prepend(String text) {
    final result = tryPrepend(text);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'String');
    }
  }

  /// Clear (convenience method)
  void clear() {
    final result = tryClear();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'String');
    }
  }

  /// Convert to uppercase (convenience method)
  void toUpperCase() {
    final result = tryToUpperCase();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'String');
    }
  }

  /// Convert to lowercase (convenience method)
  void toLowerCase() {
    final result = tryToLowerCase();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'String');
    }
  }

  /// Trim (convenience method)
  void trim() {
    final result = tryTrim();
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'String');
    }
  }

  /// Replace (convenience method)
  void replace(Pattern from, String replacement) {
    final result = tryReplace(from, replacement);
    if (result.isFailure) {
      RxLogger.logError(result.errorOrNull!, context: 'String');
    }
  }

  // ============================================================================
  // SAFE GETTERS (with tracking)
  // ============================================================================

  /// Get string length
  int get length {
    RxTracking.track(this);
    return value.length;
  }

  /// Check if string is empty
  bool get isEmpty {
    RxTracking.track(this);
    return value.isEmpty;
  }

  /// Check if string is not empty
  bool get isNotEmpty {
    RxTracking.track(this);
    return value.isNotEmpty;
  }

  /// Check if string contains substring
  bool contains(Pattern other) {
    RxTracking.track(this);
    return value.contains(other);
  }

  /// Check if string starts with prefix
  bool startsWith(Pattern pattern) {
    RxTracking.track(this);
    return value.startsWith(pattern);
  }

  /// Check if string ends with suffix
  bool endsWith(String other) {
    RxTracking.track(this);
    return value.endsWith(other);
  }

  /// Get index of substring
  int indexOf(Pattern pattern, [int start = 0]) {
    RxTracking.track(this);
    return value.indexOf(pattern, start);
  }

  /// Get last index of substring
  int lastIndexOf(Pattern pattern, [int? start]) {
    RxTracking.track(this);
    return value.lastIndexOf(pattern, start);
  }

  /// Get substring
  String substring(int startIndex, [int? endIndex]) {
    RxTracking.track(this);
    return value.substring(startIndex, endIndex);
  }

  /// Split string
  List<String> split(Pattern pattern) {
    RxTracking.track(this);
    return value.split(pattern);
  }
}