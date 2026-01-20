import '../../core/zen_exception.dart';

/// Exception thrown when a query cannot proceed due to offline network status
class ZenOfflineException extends ZenException {
  const ZenOfflineException([super.message = 'No internet connection'])
      : super(
          suggestion: 'Check your network connection or enable offline mode',
          docLink: 'https://github.com/sdegenaar/zenify#offline-first',
        );

  @override
  String get icon => '📶';

  @override
  String get category => 'Network';
}
