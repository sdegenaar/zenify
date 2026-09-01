#!/usr/bin/env dart
// tool/check_coverage.dart
//
// Parses coverage/lcov.info and enforces 100% line coverage.
// Usage:
//   dart run tool/check_coverage.dart
//   dart run tool/check_coverage.dart --threshold=99.0
//   dart run tool/check_coverage.dart --lcov=coverage/lcov.info
//
// Exit codes:
//   0 — Coverage meets or exceeds the threshold.
//   1 — Coverage is below the threshold or the lcov file is missing.

import 'dart:io';

void main(List<String> args) {
  double threshold = 100.0;
  String lcovPath = 'coverage/lcov.info';

  for (final arg in args) {
    if (arg.startsWith('--threshold=')) {
      threshold = double.parse(arg.substring('--threshold='.length));
    } else if (arg.startsWith('--lcov=')) {
      lcovPath = arg.substring('--lcov='.length);
    }
  }

  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln('❌  Coverage file not found: $lcovPath');
    stderr.writeln(
        '   Run "flutter test --coverage" first, then re-run this script.');
    exit(1);
  }

  // ── Parse lcov.info ──────────────────────────────────────────────────────
  String? currentFile;
  int totalLines = 0;
  int hitLines = 0;
  final uncoveredPerFile = <String, List<int>>{};
  final statsPerFile = <String, (int, int)>{};
  int fileTotal = 0;
  int fileHit = 0;
  final fileUncovered = <int>[];

  for (final line in lcovFile.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      currentFile = line.substring(3);
      fileTotal = 0;
      fileHit = 0;
      fileUncovered.clear();
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final lineNum = int.parse(parts[0]);
      final hitCount = int.parse(parts[1]);
      fileTotal++;
      totalLines++;
      if (hitCount > 0) {
        fileHit++;
        hitLines++;
      } else {
        fileUncovered.add(lineNum);
      }
    } else if (line == 'end_of_record' && currentFile != null) {
      statsPerFile[currentFile] = (fileHit, fileTotal);
      if (fileUncovered.isNotEmpty) {
        uncoveredPerFile[currentFile] = List.of(fileUncovered);
      }
      currentFile = null;
    }
  }

  if (totalLines == 0) {
    stderr.writeln('❌  No coverage data found in $lcovPath.');
    exit(1);
  }

  final coverage = (hitLines / totalLines) * 100;
  final passed = coverage >= threshold;

  // ── Report ───────────────────────────────────────────────────────────────
  stdout.writeln('');
  stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  stdout.writeln('  📊  Code Coverage Report');
  stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  stdout.writeln(
      '  Lines covered  : $hitLines / $totalLines  (${coverage.toStringAsFixed(2)}%)');
  stdout.writeln('  Threshold      : ${threshold.toStringAsFixed(2)}%');
  stdout.writeln('  Files tracked  : ${statsPerFile.length}');
  stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  if (uncoveredPerFile.isEmpty) {
    stdout.writeln('  ✅  All files have 100% line coverage!');
  } else {
    stdout.writeln('  ❌  Files with uncovered lines:\n');
    final sorted = uncoveredPerFile.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    for (final entry in sorted) {
      final stat = statsPerFile[entry.key]!;
      final hit = stat.$1;
      final total = stat.$2;
      final pct = (hit / total * 100).toStringAsFixed(1);
      final display = entry.key.replaceFirst(RegExp(r'^.*/lib/'), 'lib/');
      final lines = entry.value.take(20).join(', ');
      final suffix = entry.value.length > 20
          ? ' … (+${entry.value.length - 20} more)'
          : '';
      stdout.writeln('  • $display');
      stdout.writeln('    $pct% ($hit/$total) — lines: $lines$suffix\n');
    }
  }

  stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  if (passed) {
    stdout.writeln(
        '  ✅  PASSED — Coverage ${coverage.toStringAsFixed(2)}% ≥ ${threshold.toStringAsFixed(2)}%');
  } else {
    stderr.writeln(
        '  ❌  FAILED — Coverage ${coverage.toStringAsFixed(2)}% < ${threshold.toStringAsFixed(2)}%');
  }
  stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  stdout.writeln('');

  exit(passed ? 0 : 1);
}
