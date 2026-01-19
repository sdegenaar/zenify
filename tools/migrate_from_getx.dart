#!/usr/bin/env dart
// tools/migrate_from_getx.dart
// GetX to Zenify migration script

import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    print(
        'Usage: dart tools/migrate_from_getx.dart <project_path> [--dry-run]');
    print('');
    print('Options:');
    print('  --dry-run    Preview changes without modifying files');
    exit(1);
  }

  final projectPath = args[0];
  final dryRun = args.contains('--dry-run');

  print('🔄 GetX → Zenify Migration Tool');
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
      print('❌ Error: lib directory not found at $projectPath/lib');
      exit(1);
    }

    print('📂 Scanning Dart files...\n');

    // Find all .dart files
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
    var fileModified = false;

    // Apply all migrations
    final migrations = [
      // Imports
      Migration(
        'Import statement',
        RegExp(r"import 'package:get/get\.dart';"),
        "import 'package:zenify/zenify.dart';",
      ),

      // Controllers
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

      // DI - Global
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

      // Widgets
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
    ];

    for (final migration in migrations) {
      final matches = migration.pattern.allMatches(content);
      if (matches.isNotEmpty) {
        content = content.replaceAll(migration.pattern, migration.replacement);
        fileModified = true;
        replacementsMade += matches.length;
        replacementCounts[migration.name] =
            (replacementCounts[migration.name] ?? 0) + matches.length;
      }
    }

    // Check for patterns that need manual review
    final manualPatterns = [
      'Get.to(',
      'Get.back(',
      'Get.off(',
      'Get.offAll(',
      'GetMaterialApp',
      'Bindings',
      'Get.defaultDialog',
      'Get.snackbar',
    ];

    for (final pattern in manualPatterns) {
      if (content.contains(pattern)) {
        if (!manualReviewNeeded.contains(file.path)) {
          manualReviewNeeded.add(file.path);
        }
      }
    }

    // Write changes if not dry run
    if (fileModified) {
      filesModified++;

      if (!dryRun) {
        file.writeAsStringSync(content);
      }

      print('✓ ${file.path.replaceFirst(projectPath, '.')}');
    }
  }

  void printSummary() {
    print('\n' + '═' * 50);
    print('📊 Migration Summary');
    print('═' * 50);
    print('Files scanned: $filesScanned');
    print('Files modified: $filesModified');
    print('Total replacements: $replacementsMade');
    print('');

    if (replacementCounts.isNotEmpty) {
      print('Replacements by type:');
      replacementCounts.forEach((name, count) {
        print('  • $name: $count');
      });
      print('');
    }

    if (manualReviewNeeded.isNotEmpty) {
      print('⚠️  Manual review needed (${manualReviewNeeded.length} files):');
      print('These files contain GetX features that need manual migration:');
      for (final file in manualReviewNeeded) {
        print('  • ${file.replaceFirst(projectPath, '.')}');
      }
      print('');
      print('Common manual migrations:');
      print('  • Get.to() → Navigator.push()');
      print('  • Get.back() → Navigator.pop()');
      print('  • GetMaterialApp → MaterialApp');
      print('  • Bindings → ZenModule');
      print('');
    }

    if (dryRun) {
      print('🔍 DRY RUN: No files were modified');
      print('Run without --dry-run to apply changes');
    } else {
      print('✅ Migration complete!');
      print('');
      print('Next steps:');
      print('1. Update pubspec.yaml: Remove get, add zenify');
      print('2. Run: flutter pub get');
      print('3. Review files marked for manual migration');
      print('4. Test your app thoroughly');
    }
  }
}

class Migration {
  final String name;
  final RegExp pattern;
  final String replacement;

  Migration(this.name, this.pattern, this.replacement);
}
