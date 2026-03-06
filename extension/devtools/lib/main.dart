import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:zenify_devtools/src/screens/home_screen.dart';

void main() {
  runApp(const ZenifyDevToolsExtension());
}

class ZenifyDevToolsExtension extends StatelessWidget {
  const ZenifyDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(child: ZenifyDevToolsHome());
  }
}
