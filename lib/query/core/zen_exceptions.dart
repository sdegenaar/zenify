/// Exception thrown when a query cannot proceed due to offline network status
class ZenOfflineException implements Exception {
  final String message;
  const ZenOfflineException([this.message = 'No internet connection']);

  @override
  String toString() => 'ZenOfflineException: $message';
}
