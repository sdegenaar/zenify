import 'package:flutter/material.dart';
import 'counter_page.dart';
import 'todo_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenState Getx like Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'ZenState without Riverpod',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'This examples demonstrates using ZenState in "Lite mode" without '
                  'Riverpod. All local reactive state features work normally.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CounterPage()),
                );
              },
              child: const Text('Counter Example'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TodoPage()),
                );
              },
              child: const Text('Todo List Example'),
            ),
          ],
        ),
      ),
    );
  }
}