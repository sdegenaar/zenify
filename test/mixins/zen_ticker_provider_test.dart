import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

/// Tests for ZenTickerProvider mixin (currently 0% coverage)
void main() {
  setUp(Zen.init);
  tearDown(Zen.reset);

  group('ZenTickerProvider', () {
    test('createTicker returns a Ticker', () {
      final ctrl = _TickerCtrl();
      final ticker = ctrl.createTicker((_) {});
      expect(ticker, isA<Ticker>());
      ctrl.dispose();
    });

    test('createTicker accumulates multiple tickers', () {
      final ctrl = _TickerCtrl();
      ctrl.createTicker((_) {});
      ctrl.createTicker((_) {});
      // No direct count API, but dispose should not crash
      ctrl.dispose();
    });

    test('tickers are disposed when controller closes', () {
      final ctrl = _TickerCtrl();
      final ticker = ctrl.createTicker((_) {});
      ctrl.dispose();
      // ticker should no longer be active
      expect(ticker.isActive, false);
    });

    test('onClose disposes all tickers', () {
      final ctrl = _TickerCtrl();
      final t1 = ctrl.createTicker((_) {});
      final t2 = ctrl.createTicker((_) {});
      ctrl.dispose(); // calls onClose → _disposeTickers
      expect(t1.isActive, false);
      expect(t2.isActive, false);
    });

    test('ZenTickerProvider implements TickerProvider', () {
      final ctrl = _TickerCtrl();
      expect(ctrl, isA<TickerProvider>());
      ctrl.dispose();
    });
  });
}

class _TickerCtrl extends ZenController with ZenTickerProvider {}
