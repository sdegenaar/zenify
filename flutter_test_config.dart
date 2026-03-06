import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Disable shader warmup in tests to avoid ink_sparkle.frag errors
  // This is a known issue with Flutter tests and Material 3
  TestWidgetsFlutterBinding.ensureInitialized();

  // Disable shader warmup globally for tests
  debugDisableShadows = true;

  await testMain();
}
