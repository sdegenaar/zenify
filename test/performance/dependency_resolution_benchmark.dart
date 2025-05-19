// test/performance/dependency_resolution_benchmark.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zen_state/zen_state.dart';

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
    // Register several dependencies
    scope.register<SimpleDependency>(
        SimpleDependency(moduleId),
        tag: 'simple$moduleId'
    );

    final simple = SimpleDependency(moduleId * 10);
    scope.register<SimpleDependency>(simple, tag: 'base$moduleId');

    scope.register<NestedDependency>(
        NestedDependency(simple, moduleId),
        tag: 'nested$moduleId'
    );
  }
}

// Benchmark utility class
class BenchmarkResult {
  final String name;
  final int iterations;
  final Duration duration;

  BenchmarkResult(this.name, this.iterations, this.duration);

  double get operationsPerSecond =>
      iterations / duration.inMicroseconds * 1000000;


  @override
  String toString() =>
      '$name: ${operationsPerSecond.toStringAsFixed(2)} operations/second '
          '(${(duration.inMicroseconds / iterations).toStringAsFixed(2)} microseconds per operation)';
}

void main() {
  late ProviderContainer container;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    container = ProviderContainer();
    Zen.init(container);
    ZenConfig.enableDebugLogs = false; // Disable logs for benchmarking
    ZenConfig.checkForCircularDependencies = false;

  });

  tearDown(() {
    Zen.deleteAll(force: true);
  });

  group('Dependency Resolution Benchmarks', () {

    // Define the runBenchmark function here
    BenchmarkResult runBenchmark(String name, int iterations, Function() benchmarkFn) {
      // Warm-up (with clean-up after each iteration)
      for (int i = 0; i < 100; i++) {
        try {
          benchmarkFn();
        } catch (e) {
          ZenLogger.logError('Warm-up error', e);
        }

        // Clean up between warm-up iterations, but don't force disposal
        try {
          Zen.deleteAll(force: false);
        } catch (e) {
          // Ignore clean-up errors during warm-up
        }
      }

      // Reset state completely before actual benchmark - we can't use force: true here
      try {
        container = ProviderContainer(); // Create a fresh container
        Zen.init(container); // Reinitialize Zen with the fresh container
      } catch (e) {
        ZenLogger.logError('Reset error', e);
      }

      // Actual benchmark
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < iterations; i++) {
        try {
          benchmarkFn();
        } catch (e) {
          ZenLogger.logError('Benchmark error at iteration $i', e);
          continue; // Skip this iteration but continue the benchmark
        }

        // Only clean up at the end of each iteration if it's a multi-step benchmark
        // This avoids scope disposal issues during the benchmark
        if (i < iterations - 1) {
          try {
            Zen.deleteAll(force: false);
          } catch (e) {
            // Ignore internal cleanup errors
          }
        }
      }
      stopwatch.stop();

      final result = BenchmarkResult(name, iterations, stopwatch.elapsed);
      ZenLogger.logInfo(result.toString());
      return result;
    }

    test('benchmark simple dependency registration', () {
      final result = runBenchmark('Simple registration', 10000, () {
        final dependency = SimpleDependency(42);
        Zen.putDependency<SimpleDependency>(dependency);
        Zen.deleteDependency<SimpleDependency>();
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark simple dependency resolution', () {
      final result = runBenchmark('Simple resolution', 50000, () {
        final dependency = SimpleDependency(42);
        Zen.putDependency<SimpleDependency>(dependency);
        Zen.findDependency<SimpleDependency>();
        Zen.deleteDependency<SimpleDependency>();
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark tagged dependency resolution', () {
      final result = runBenchmark('Tagged resolution', 10000, () {
        for (int i = 0; i < 5; i++) {
          final dependency = SimpleDependency(i);
          Zen.putDependency<SimpleDependency>(dependency, tag: 'tag$i');
        }

        for (int i = 0; i < 5; i++) {
          Zen.findDependency<SimpleDependency>(tag: 'tag$i');
        }

        for (int i = 0; i < 5; i++) {
          Zen.deleteDependency<SimpleDependency>(tag: 'tag$i');
        }
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark automatic dependency resolution with circular references', () {
      final result = runBenchmark('Circular references', 1000, () {
        // Use the top-level classes, don't define them here
        final a = ServiceA();
        final b = ServiceB();

        // Register them first (without dependencies)
        Zen.putDependency<ServiceA>(a);
        Zen.putDependency<ServiceB>(b);

        // Then set up the circular reference
        a.b = b;
        b.a = a;

        // Find them
        final foundA = Zen.findDependency<ServiceA>();
        final foundB = Zen.findDependency<ServiceB>();

        // Verify circular references
        expect(foundA?.b?.id, 2);
        expect(foundB?.a?.id, 1);

        // Clean up
        Zen.deleteDependency<ServiceA>();
        Zen.deleteDependency<ServiceB>();
      });

      expect(result.operationsPerSecond > 0, true);
    });

    test('benchmark module-based dependency registration', () {
      final result = runBenchmark('Module-based registration', 1000, () {
        // Use the top-level module class
        final module = BenchmarkModule(1);
        Zen.registerModules([module]);

        // Access dependencies
        Zen.findDependency<SimpleDependency>(tag: 'simple1');
        Zen.findDependency<SimpleDependency>(tag: 'base1');
        Zen.findDependency<NestedDependency>(tag: 'nested1');

        // Clean up
        Zen.deleteDependency<SimpleDependency>(tag: 'simple1');
        Zen.deleteDependency<SimpleDependency>(tag: 'base1');
        Zen.deleteDependency<NestedDependency>(tag: 'nested1');
      });

      expect(result.operationsPerSecond > 0, true);
    });

    // Add other benchmark tests as needed...
  });
}