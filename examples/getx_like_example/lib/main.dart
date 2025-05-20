import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';
import '../pages/home_page.dart';

void main() {
  // Initialize ZenState in "Lite mode" (without Riverpod)
  ZenConfig.applyEnvironment('dev'); // Optional configuration

  // Enable logging for demonstration purposes
  ZenConfig.enableDebugLogs = true;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZenState GetX like Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}