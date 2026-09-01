#!/usr/bin/env dart
// tool/install_hooks.dart
//
// Installs the Zenify pre-commit hook into the local .git/hooks/ directory.
// Run once after cloning:
//
//   dart run tool/install_hooks.dart
//
// The hook enforces:
//   1. dart format (no unstaged formatting changes)
//   2. flutter analyze (no warnings/errors)
//   3. flutter test --coverage + 100% coverage gate

import 'dart:io';

const hookContent = r'''
#!/usr/bin/env bash
# Zenify pre-commit hook — installed by tool/install_hooks.dart
# Enforces formatting, static analysis, and 100% code coverage.

set -euo pipefail

BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)

echo ""
echo "${BOLD}🔍  Zenify pre-commit checks${RESET}"
echo "─────────────────────────────────────"

# ── 1. Format ──────────────────────────────────────────────────────────────
echo "${BOLD}[1/3]${RESET} Checking code format…"
if ! dart format --output=none --set-exit-if-changed lib test > /dev/null 2>&1; then
  echo "${RED}✗  Format check failed.${RESET}"
  echo "   Run ${BOLD}dart format lib test${RESET} and stage the changes, then try again."
  exit 1
fi
echo "${GREEN}✓  Format OK${RESET}"

# ── 2. Analyze ─────────────────────────────────────────────────────────────
echo "${BOLD}[2/3]${RESET} Running static analysis…"
if ! flutter analyze --fatal-infos > /tmp/zen_analyze.txt 2>&1; then
  echo "${RED}✗  Analysis failed:${RESET}"
  cat /tmp/zen_analyze.txt
  exit 1
fi
echo "${GREEN}✓  Analysis OK${RESET}"

# ── 3. Tests + Coverage ────────────────────────────────────────────────────
echo "${BOLD}[3/3]${RESET} Running tests and checking coverage…"
echo "       ${YELLOW}(this may take ~30s — hang tight)${RESET}"

if ! flutter test --coverage > /tmp/zen_tests.txt 2>&1; then
  echo "${RED}✗  Tests failed:${RESET}"
  tail -30 /tmp/zen_tests.txt
  exit 1
fi

if ! dart run tool/check_coverage.dart; then
  echo "${RED}✗  Coverage gate failed — commit blocked.${RESET}"
  exit 1
fi

echo "─────────────────────────────────────"
echo "${GREEN}${BOLD}✅  All checks passed — committing!${RESET}"
echo ""
''';

void main() {
  final hookDir = Directory('.git/hooks');
  if (!hookDir.existsSync()) {
    stderr.writeln('❌  .git/hooks directory not found.');
    stderr.writeln('   Make sure you are running this from the repo root.');
    exit(1);
  }

  final hookFile = File('.git/hooks/pre-commit');
  hookFile.writeAsStringSync(hookContent);

  // Make executable
  final result = Process.runSync('chmod', ['+x', hookFile.path]);
  if (result.exitCode != 0) {
    stderr.writeln('❌  Failed to make hook executable: ${result.stderr}');
    exit(1);
  }

  stdout.writeln('');
  stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  stdout.writeln('  ✅  Pre-commit hook installed!');
  stdout.writeln('');
  stdout.writeln('  Location : .git/hooks/pre-commit');
  stdout.writeln('');
  stdout.writeln('  The hook will enforce on every commit:');
  stdout.writeln('    1. dart format  — no unstaged format changes');
  stdout.writeln('    2. flutter analyze — no warnings or errors');
  stdout.writeln('    3. flutter test --coverage + 100% gate');
  stdout.writeln('');
  stdout.writeln('  To skip in emergencies (use sparingly):');
  stdout.writeln('    git commit --no-verify');
  stdout.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  stdout.writeln('');
}
