import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:zenify_devtools/src/models/metrics_data.dart';

/// Service for fetching Zenify system metrics
class MetricsService {
  /// Fetch current system metrics
  Future<ZenifyMetrics> getMetrics() async {
    try {
      final response = await serviceManager.service!.callServiceExtension(
        'ext.zenify.getMetrics',
      );

      return ZenifyMetrics.fromJson(
        response.json!['metrics'] as Map<String, dynamic>,
      );
    } catch (e) {
      return _getMockMetrics();
    }
  }

  /// Mock metrics for development
  ZenifyMetrics _getMockMetrics() {
    return const ZenifyMetrics(
      totalScopes: 8,
      activeScopes: 5,
      disposedScopes: 3,
      totalControllers: 12,
      totalServices: 6,
      totalQueries: 15,
      activeQueries: 12,
      cachedQueries: 15,
      globalQueries: 8,
      scopedQueries: 7,
      loadingQueries: 2,
      errorQueries: 1,
      staleQueries: 4,
      memory: MemoryMetrics(
        currentRss: 145678912,
        currentHeapSize: 89456128,
        currentHeapUsed: 67234816,
      ),
    );
  }
}
