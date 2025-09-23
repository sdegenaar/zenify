import 'package:flutter/scheduler.dart';

import '../controllers/zen_controller.dart';

mixin ZenTickerProvider on ZenController implements TickerProvider {
  final List<Ticker> _tickers = [];

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    _tickers.add(ticker);
    return ticker;
  }

  void _disposeTickers() {
    for (final ticker in _tickers) {
      ticker.dispose();
    }
    _tickers.clear();
  }

  @override
  void onClose() {
    _disposeTickers();
    super.onClose();
  }
}
