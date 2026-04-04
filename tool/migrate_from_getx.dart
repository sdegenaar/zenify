#!/usr/bin/env dart
// tool/migrate_from_getx.dart
// GetX to Zenify migration script
// ignore_for_file: avoid_print

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart tool/migrate_from_getx.dart <project_path> [--dry-run]');
    print('');
    print('Options:');
    print('  --dry-run    Preview changes without modifying files');
    print('');
    print('Example:');
    print('  dart tool/migrate_from_getx.dart /path/to/my_app --dry-run');
    exit(1);
  }

  final projectPath = args[0];
  final dryRun = args.contains('--dry-run');

  print('GetX → Zenify Migration Tool');
  print('═' * 50);
  print('Project: $projectPath');
  print(
      'Mode: ${dryRun ? 'DRY RUN (preview only)' : 'LIVE (will modify files)'}');
  print('');

  final migrator = GetXMigrator(projectPath, dryRun: dryRun);
  migrator.migrate();
}

class GetXMigrator {
  final String projectPath;
  final bool dryRun;

  int filesScanned = 0;
  int filesModified = 0;
  int replacementsMade = 0;
  final List<String> manualReviewNeeded = [];
  final Map<String, int> replacementCounts = {};

  GetXMigrator(this.projectPath, {this.dryRun = false});

  void migrate() {
    final libDir = Directory('$projectPath/lib');

    if (!libDir.existsSync()) {
      print('Error: lib directory not found at $projectPath/lib');
      exit(1);
    }

    print('Scanning Dart files...\n');

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    for (final file in dartFiles) {
      processFile(file);
    }

    printSummary();
  }

  void processFile(File file) {
    filesScanned++;

    final originalContent = file.readAsStringSync();
    var content = originalContent;

    // Apply all mechanical migrations in order
    final migrations = [
      // ── Imports ──────────────────────────────────────────────────────────
      Migration(
        'Import statement',
        RegExp(r"import 'package:get/get\.dart';"),
        "import 'package:zenify/zenify.dart';",
      ),

      // ── Controllers & Services ───────────────────────────────────────────
      Migration(
        'GetxController → ZenController',
        RegExp(r'\bGetxController\b'),
        'ZenController',
      ),
      Migration(
        'GetxService → ZenService',
        RegExp(r'\bGetxService\b'),
        'ZenService',
      ),

      // ── Reactive values ──────────────────────────────────────────────────
      // Must run BEFORE any other .obs replacement to avoid double-converting.
      // Matches .obs NOT already followed by ( — safe for .obscure, .observe etc.
      Migration(
        '.obs → .obs()',
        RegExp(r'\.obs\b(?!\()'),
        '.obs()',
      ),

      // ── Dependency injection ─────────────────────────────────────────────
      Migration(
        'Get.put → Zen.put',
        RegExp(r'\bGet\.put\b'),
        'Zen.put',
      ),
      Migration(
        'Get.lazyPut → Zen.putLazy',
        RegExp(r'\bGet\.lazyPut\b'),
        'Zen.putLazy',
      ),
      Migration(
        'Get.find → Zen.find',
        RegExp(r'\bGet\.find\b'),
        'Zen.find',
      ),
      Migration(
        'Get.delete → Zen.delete',
        RegExp(r'\bGet\.delete\b'),
        'Zen.delete',
      ),
      Migration(
        'Get.isRegistered → Zen.has',
        RegExp(r'\bGet\.isRegistered\b'),
        'Zen.has',
      ),

      // ── Widgets ──────────────────────────────────────────────────────────
      Migration(
        'GetBuilder → ZenBuilder',
        RegExp(r'\bGetBuilder\b'),
        'ZenBuilder',
      ),
      Migration(
        'GetView → ZenView',
        RegExp(r'\bGetView\b'),
        'ZenView',
      ),
      // GetX<T> reactive widget — maps to ZenBuilder<T>
      // Note: only matches the widget usage, not the package name
      Migration(
        'GetX widget → ZenBuilder',
        RegExp(r'\bGetX<'),
        'ZenBuilder<',
      ),

      // ── Parameter renames ────────────────────────────────────────────────
      // permanent: → isPermanent: (parameter name changed in Zenify)
      Migration(
        'permanent: → isPermanent:',
        RegExp(r'\bpermanent:'),
        'isPermanent:',
      ),
    ];

    for (final migration in migrations) {
      final matches = migration.pattern.allMatches(content);
      if (matches.isNotEmpty) {
        content = content.replaceAll(migration.pattern, migration.replacement);
        replacementsMade += matches.length;
        replacementCounts[migration.name] =
            (replacementCounts[migration.name] ?? 0) + matches.length;
      }
    }

    // ── Flag patterns requiring manual rewrite ────────────────────────────
    final manualPatterns = {
      'Get.to(': 'Navigation: use Navigator.push() or GoRouter',
      'Get.back(': 'Navigation: use Navigator.pop()',
      'Get.off(': 'Navigation: use Navigator.pushReplacement()',
      'Get.offAll(': 'Navigation: use Navigator.pushAndRemoveUntil()',
      'GetMaterialApp': 'Replace with MaterialApp — no wrapper needed',
      'extends Bindings': 'Convert to ZenModule with register(ZenScope scope)',
      'Get.putAsync': 'Use Zen.put() with await in onInit() instead',
      'Get.defaultDialog': 'Use showDialog() from Flutter',
      'Get.snackbar': 'Use ScaffoldMessenger.of(context).showSnackBar()',
      'Get.bottomSheet': 'Use showModalBottomSheet() from Flutter',
      'Get.context':
          'No global context in Zenify — pass BuildContext explicitly',
      'GetStorage':
          'Implement ZenStorage interface — see doc/migration_guide.md',
      '.tr': 'GetX i18n not available in Zenify — use flutter_localizations',
      // Top-level GetX worker functions need ZenWorkers. prefix
      'ever(': 'Worker: use ZenWorkers.ever() inside onInit()',
      'once(': 'Worker: use ZenWorkers.once() inside onInit()',
      'debounce(': 'Worker: use ZenWorkers.debounce() inside onInit()',
      'interval(': 'Worker: use ZenWorkers.interval() inside onInit()',
    };

    final flaggedReasons = <String>[];
    for (final entry in manualPatterns.entries) {
      if (content.contains(entry.key)) {
        if (!manualReviewNeeded.contains(file.path)) {
          manualReviewNeeded.add(file.path);
        }
        flaggedReasons.add('  → ${entry.key.trim()}: ${entry.value}');
      }
    }

    if (content != originalContent) {
      filesModified++;
      if (!dryRun) {
        file.writeAsStringSync(content);
      }
      final relativePath = file.path.replaceFirst(projectPath, '.');
      print('  ${dryRun ? '[preview]' : '[updated]'} $relativePath');
    }

    if (flaggedReasons.isNotEmpty) {
      final relativePath = file.path.replaceFirst(projectPath, '.');
      print('  [manual]  $relativePath');
      for (final reason in flaggedReasons) {
        print('            $reason');
      }
    }
  }

  void printSummary() {
    print('\n${'═' * 50}');
    print('Migration Summary');
    print('═' * 50);
    print('Files scanned:    $filesScanned');
    print('Files modified:   $filesModified');
    print('Total replacements: $replacementsMade');
    print('Manual review:    ${manualReviewNeeded.length} files');

    if (replacementCounts.isNotEmpty) {
      print('\nReplacements made:');
      replacementCounts.forEach((name, count) {
        print('  $count × $name');
      });
    }

    if (manualReviewNeeded.isNotEmpty) {
      print('\nFiles needing manual changes:');
      for (final file in manualReviewNeeded) {
        print('  • ${file.replaceFirst(projectPath, '.')}');
      }
      print('\nSee doc/migration_guide.md for guidance on each pattern.');
    }

    print('');
    if (dryRun) {
      print('DRY RUN — no files were modified.');
      print('Remove --dry-run to apply changes.');
    } else {
      print('Next steps:');
      print('  1. Update pubspec.yaml: remove "get:", add "zenify: ^1.9.1"');
      print('  2. Run: flutter pub get');
      print('  3. Run: dart analyze   (find any remaining issues)');
      print('  4. Fix files marked [manual] above');
      print('  5. Run: flutter test');
      print('');
      print('Migration complete. See doc/migration_guide.md for manual steps.');
    }
  }
}

class Migration {
  final String name;
  final RegExp pattern;
  final String replacement;

  Migration(this.name, this.pattern, this.replacement);
}
