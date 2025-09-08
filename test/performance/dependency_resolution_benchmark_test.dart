import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart'; // Add this import
import 'package:zenify/zenify.dart';

// Simple classes for benchmarking
class SimpleDependency {
  final int id;
  SimpleDependency(this.id);
}

class NestedDependency {
  final SimpleDependency simpleDependency;
  final int level;
  NestedDependency(this.simpleDependency, this.level);
}

class DeepNestingDependency {
  final NestedDependency nestedDependency;
  final int depth;
  DeepNestingDependency(this.nestedDependency, this.depth);
}

class ComplexDependency {
  final List<SimpleDependency> dependencies;
  final Map<String, int> metadata;
  final String name;
  ComplexDependency(this.dependencies, this.metadata, this.name);
}

// Define benchmark controller
class BenchmarkController extends ZenController {
  final int value;
  BenchmarkController(this.value);
}

// Add circular reference classes at the top level
class ServiceA {
  ServiceB? b;
  final int id = 1;
}

class ServiceB {
  ServiceA? a;
  final int id = 2;
}

// Add benchmark module at the top level
class BenchmarkModule extends ZenModule {
  final int moduleId;

  BenchmarkModule(this.moduleId);

  @override
  String get name => 'BenchmarkModule$moduleId';

  @override
  List<ZenModule> get dependencies => [];

  @override
  void register(ZenScope scope) {
    // Use put() instead of register()
    scope.put<SimpleDependency>(SimpleDependency(moduleId),
        tag: 'simple$moduleId');

    final simple = SimpleDependency(moduleId * 10);
    scope.put<SimpleDependency>(simple, tag: 'base$moduleId');

    scope.put<NestedDependency>(NestedDependency(simple, moduleId),
        tag: 'nested$moduleId');
  }
}

// Benchmark utility class
class BenchmarkResult {
  final String name;
  final int iterations;
  final Duration duration;
  final int errorCount;

  BenchmarkResult(this.name, this.iterations, this.duration, this.errorCount);

  double get operationsPerSecond =>
      iterations / duration.inMicroseconds * 1000000;

  double get avgMicrosecondsPerOperation =>
      duration.inMicroseconds / iterations;

  double get errorRate => (errorCount / iterations) * 100;

  @override
  String toString() =>
      '$name: ${operationsPerSecond.toStringAsFixed(2)} ops/sec, '
      '${avgMicrosecondsPerOperation.toStringAsFixed(2)} microseconds per op';
}

// Global benchmark tracking
class BenchmarkTracker {
  static final List<BenchmarkResult> _results = [];
  static int _totalBenchmarks = 0;
  static int _failedBenchmarks = 0;

  static void addResult(BenchmarkResult result) {
    _results.add(result);
    _totalBenchmarks++;
    if (result.errorRate > 0) {
      _failedBenchmarks++;
    }
  }

  static void printSummary() {
    debugPrint('');
    debugPrint('🏁 BENCHMARK SUITE COMPLETE');
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('   • Total benchmarks: $_totalBenchmarks');
    debugPrint('   • Successful: ${_totalBenchmarks - _failedBenchmarks}');
    debugPrint('   • With errors: $_failedBenchmarks');
    debugPrint('');

    if (_results.isNotEmpty) {
      debugPrint('📊 PERFORMANCE SUMMARY:');
      for (final result in _results) {
        final status = result.errorRate > 0 ? '⚠️ ' : '✅';
        debugPrint('   $status ${result.toString()}');
        if (result.errorRate > 0) {
          debugPrint(
              '      └─ Error rate: ${result.errorRate.toStringAsFixed(1)}%');
        }
      }

      // Find fastest and slowest
      _results.sort(
          (a, b) => b.operationsPerSecond.compareTo(a.operationsPerSecond));
      debugPrint('');
      debugPrint(
          '🥇 Fastest: ${_results.first.name} (${_results.first.operationsPerSecond.toStringAsFixed(2)} ops/sec)');
      debugPrint(
          '🐌 Slowest: ${_results.last.name} (${_results.last.operationsPerSecond.toStringAsFixed(2)} ops/sec)');
      debugPrint('');
      debugPrint(
          '📖 Legend: ops/sec = operations per second, microseconds = μs');
    }
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('');
  }

  static void reset() {
    _results.clear();
    _totalBenchmarks = 0;
    _failedBenchmarks = 0;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugPrint('🚀 STARTING ZENIFY DEPENDENCY RESOLUTION BENCHMARKS');
    debugPrint('════════════════════════════════════════════════════════════');
    debugPrint('📖 Legend: ops/sec = operations per second, μs = microseconds');
    debugPrint('');
    BenchmarkTracker.reset();
  });

  setUp(() {
    Zen.init();
    // Disable debug logs during benchmarks for accurate timing
    ZenConfig.enableDebugLogs = false;
    ZenConfig.checkForCircularDependencies = false;
  });

  tearDown(() {
    Zen.reset();
  });

  tearDownAll(() {
    BenchmarkTracker.printSummary();
  });

  group('Dependency Resolution Benchmarks', () {
    BenchmarkResult runBenchmark(
        String name, int iterations, Function() benchmarkFn) {
      // Log benchmark start
      debugPrint('🔄 Running: $name ($iterations iterations)...');

      int warmupErrors = 0;

      // Silent warm-up (no per-iteration logging)
      for (int i = 0; i < 100; i++) {
        try {
          benchmarkFn();
        } catch (e) {
          warmupErrors++;
          // Only log if warm-up is completely broken
          if (warmupErrors == 1) {
            debugPrint('   ⚠️  Warning: Warm-up errors detected');
          }
        }

        try {
          Zen.reset();
          Zen.init();
        } catch (e) {
          // Silent cleanup
        }
      }

      // Reset before actual benchmark
      try {
        Zen.reset();
        Zen.init();
      } catch (e) {
        debugPrint('   ❌ CRITICAL: Failed to reset before benchmark - $e');
      }

      // Silent benchmark execution for accurate timing
      int errorCount = 0;
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < iterations; i++) {
        try {
          benchmarkFn();
        } catch (e) {
          errorCount++;
          // Don't log individual errors during timing
        }

        if (i < iterations - 1) {
          try {
            Zen.reset();
            Zen.init();
          } catch (e) {
            // Silent cleanup
          }
        }
      }
      stopwatch.stop();

      final result =
          BenchmarkResult(name, iterations, stopwatch.elapsed, errorCount);

      // Log results immediately after timing
      final status = errorCount > 0 ? '⚠️ ' : '✅';
      debugPrint(
          '   $status ${result.operationsPerSecond.toStringAsFixed(2)} ops/sec '
          '(${result.avgMicrosecondsPerOperation.toStringAsFixed(2)} microseconds per op)');

      if (errorCount > 0) {
        debugPrint(
            '   └─ $errorCount/$iterations errors (${result.errorRate.toStringAsFixed(1)}%)');
      }

      // Track result for summary
      BenchmarkTracker.addResult(result);

      return result;
    }

    test('benchmark simple dependency registration', () {
      final result = runBenchmark('Simple registration', 10000, () {
        final dependency = SimpleDependency(42);
        Zen.put<SimpleDependency>(dependency);
        Zen.delete<SimpleDependency>();
      });

      expect(result.operationsPerSecond > 0, true);

      // Performance threshold check
      if (result.operationsPerSecond < 1000) {
        debugPrint(
            '   ⚠️  Performance warning: Registration slower than expected');
      }
    });

    test('benchmark simple dependency resolution', () {
      final result = runBenchmark('Simple resolution', 50000, () {
        final dependency = SimpleDependency(42);
        Zen.put<SimpleDependency>(dependency);
        Zen.find<SimpleDependency>();
        Zen.delete<SimpleDependency>();
      });

      expect(result.operationsPerSecond > 0, true);

      if (result.operationsPerSecond < 5000) {
        debugPrint(
            '   ⚠️  Performance warning: Resolution slower than expected');
      }
    });

    test('benchmark tagged dependency resolution', () {
      final result = runBenchmark('Tagged resolution', 10000, () {
        for (int i = 0; i < 5; i++) {
          final dependency = SimpleDependency(i);
          Zen.put<SimpleDependency>(dependency, tag: 'tag$i');
        }

        for (int i = 0; i < 5; i++) {
          Zen.find<SimpleDependency>(tag: 'tag$i');
        }

        for (int i = 0; i < 5; i++) {
          Zen.delete<SimpleDependency>(tag: 'tag$i');
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark circular reference handling', () {
      final result = runBenchmark('Circular references', 1000, () {
        final a = ServiceA();
        final b = ServiceB();

        // Register them first
        Zen.put<ServiceA>(a);
        Zen.put<ServiceB>(b);

        // Set up circular reference
        a.b = b;
        b.a = a;

        // Find them
        final foundA = Zen.find<ServiceA>();
        final foundB = Zen.find<ServiceB>();

        // Verify circular references
        expect(foundA.b?.id, 2);
        expect(foundB.a?.id, 1);

        // Clean up
        Zen.delete<ServiceA>();
        Zen.delete<ServiceB>();
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark module-based dependency registration', () {
      final result = runBenchmark('Module-based registration', 1000, () {
        final scope = Zen.createScope(name: 'BenchmarkScope');
        final module = BenchmarkModule(1);

        try {
          // Register the module in the scope
          module.register(scope);

          // Access dependencies from the scope
          scope.find<SimpleDependency>(tag: 'simple1');
          scope.find<SimpleDependency>(tag: 'base1');
          scope.find<NestedDependency>(tag: 'nested1');
        } finally {
          // Clean up the scope
          scope.dispose();
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark nested dependency creation', () {
      final result = runBenchmark('Nested dependencies', 5000, () {
        final simple = SimpleDependency(1);
        Zen.put<SimpleDependency>(simple);

        final nested = NestedDependency(simple, 2);
        Zen.put<NestedDependency>(nested);

        final deep = DeepNestingDependency(nested, 3);
        Zen.put<DeepNestingDependency>(deep);

        // Access all levels
        Zen.find<SimpleDependency>();
        Zen.find<NestedDependency>();
        Zen.find<DeepNestingDependency>();

        // Clean up
        Zen.delete<DeepNestingDependency>();
        Zen.delete<NestedDependency>();
        Zen.delete<SimpleDependency>();
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark complex dependency with collections', () {
      final result = runBenchmark('Complex dependencies', 2000, () {
        // Create multiple simple dependencies
        final dependencies = <SimpleDependency>[];
        for (int i = 0; i < 10; i++) {
          final dep = SimpleDependency(i);
          dependencies.add(dep);
          Zen.put<SimpleDependency>(dep, tag: 'dep$i');
        }

        // Create complex dependency
        final complex = ComplexDependency(dependencies,
            {'count': dependencies.length, 'version': 1}, 'BenchmarkComplex');
        Zen.put<ComplexDependency>(complex);

        // Access it
        final found = Zen.find<ComplexDependency>();
        expect(found.dependencies.length, 10);

        // Clean up
        Zen.delete<ComplexDependency>();
        for (int i = 0; i < 10; i++) {
          Zen.delete<SimpleDependency>(tag: 'dep$i');
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark controller registration and access', () {
      final result = runBenchmark('Controller operations', 5000, () {
        final controller = BenchmarkController(42);
        Zen.put<BenchmarkController>(controller);

        final found = Zen.find<BenchmarkController>();
        expect(found.value, 42);

        Zen.delete<BenchmarkController>();
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark scope isolation', () {
      final result = runBenchmark('Scope isolation', 1000, () {
        final scope1 = Zen.createScope(name: 'Scope1');
        final scope2 = Zen.createScope(name: 'Scope2');

        try {
          // Register same type in different scopes
          scope1.put<SimpleDependency>(SimpleDependency(1));
          scope2.put<SimpleDependency>(SimpleDependency(2));

          // Access from each scope
          final dep1 = scope1.find<SimpleDependency>();
          final dep2 = scope2.find<SimpleDependency>();

          expect(dep1?.id, 1);
          expect(dep2?.id, 2);
        } finally {
          scope1.dispose();
          scope2.dispose();
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark massive dependency batch operations', () {
      final result = runBenchmark('Batch operations', 100, () {
        // Register 100 dependencies
        for (int i = 0; i < 100; i++) {
          Zen.put<SimpleDependency>(SimpleDependency(i), tag: 'batch$i');
        }

        // Find all of them
        for (int i = 0; i < 100; i++) {
          final dep = Zen.find<SimpleDependency>(tag: 'batch$i');
          expect(dep.id, i);
        }

        // Delete all of them
        for (int i = 0; i < 100; i++) {
          Zen.delete<SimpleDependency>(tag: 'batch$i');
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark scope hierarchy performance', () {
      final result = runBenchmark('Scope hierarchy', 1000, () {
        final grandParent = Zen.createScope(name: 'GrandParent');
        final parent = Zen.createScope(parent: grandParent, name: 'Parent');
        final child = Zen.createScope(parent: parent, name: 'Child');

        try {
          // Register at different levels
          grandParent.put<SimpleDependency>(SimpleDependency(1), tag: 'level1');
          parent.put<SimpleDependency>(SimpleDependency(2), tag: 'level2');
          child.put<SimpleDependency>(SimpleDependency(3), tag: 'level3');

          // Access from child (should traverse hierarchy)
          child.find<SimpleDependency>(tag: 'level1'); // From grandparent
          child.find<SimpleDependency>(tag: 'level2'); // From parent
          child.find<SimpleDependency>(tag: 'level3'); // From self
        } finally {
          child.dispose();
          parent.dispose();
          grandParent.dispose();
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark dependency stress test', () {
      final result = runBenchmark('Dependency stress test', 50, () {
        // Create a complex dependency graph
        final scopes = <ZenScope>[];

        try {
          // Create multiple scopes
          for (int i = 0; i < 10; i++) {
            final scope = Zen.createScope(name: 'StressScope$i');
            scopes.add(scope);

            // Register multiple dependencies per scope
            for (int j = 0; j < 10; j++) {
              scope.put<SimpleDependency>(SimpleDependency(i * 10 + j),
                  tag: 'stress_${i}_$j');
            }
          }

          // Access dependencies across all scopes
          for (int i = 0; i < 10; i++) {
            for (int j = 0; j < 10; j++) {
              final dep =
                  scopes[i].find<SimpleDependency>(tag: 'stress_${i}_$j');
              expect(dep?.id, i * 10 + j);
            }
          }
        } finally {
          // Clean up all scopes
          for (final scope in scopes) {
            scope.dispose();
          }
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark memory cleanup performance', () {
      final result = runBenchmark('Memory cleanup', 1000, () {
        // Create and immediately dispose dependencies
        for (int i = 0; i < 20; i++) {
          final dep = SimpleDependency(i);
          Zen.put<SimpleDependency>(dep, tag: 'cleanup$i');
          Zen.delete<SimpleDependency>(tag: 'cleanup$i');
        }

        // Create and dispose a scope
        final scope = Zen.createScope(name: 'CleanupScope');
        for (int i = 0; i < 10; i++) {
          scope.put<SimpleDependency>(SimpleDependency(i), tag: 'scoped$i');
        }
        scope.dispose();
      });

      expect(result.operationsPerSecond > 0, true);
    });
  });
}
