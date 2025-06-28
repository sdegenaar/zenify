class DemoService {
  // Simulate API calls and data operations

  Future<String> fetchData({Duration delay = const Duration(seconds: 2)}) async {
    await Future.delayed(delay);
    return 'Data fetched at ${DateTime.now().toIso8601String()}';
  }

  Future<List<String>> fetchItems({bool shouldFail = false}) async {
    await Future.delayed(const Duration(seconds: 1));

    if (shouldFail) {
      throw Exception('Failed to fetch items');
    }

    return [
      'Item 1 - ${DateTime.now().millisecond}',
      'Item 2 - ${DateTime.now().millisecond}',
      'Item 3 - ${DateTime.now().millisecond}',
    ];
  }

  Future<bool> performAction({bool shouldSucceed = true}) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!shouldSucceed) {
      throw Exception('Action failed');
    }

    return true;
  }
}