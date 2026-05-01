import 'package:flutter_test/flutter_test.dart';
import 'package:zenify/zenify.dart';

void main() {
  test('maxPages limits the number of pages kept in memory', () async {
    final query = ZenInfiniteQuery<int>(
      queryKey: 'maxPagesTest',
      maxPages: 2,
      initialPageParam: 0,
      infiniteFetcher: (page, token) async => page as int,
      getNextPageParam: (lastPage, pages) => lastPage + 1,
      getPreviousPageParam: (firstPage, pages) => firstPage - 1,
    );

    // Initial fetch -> [0]
    final res1 = await query.fetch();
    expect(res1, [0]);
    expect(query.data.value, [0]);

    // Fetch next -> [0, 1]
    await query.fetchNextPage();
    expect(query.data.value, [0, 1]);

    // Fetch next -> should keep last 2 pages -> [1, 2]
    await query.fetchNextPage();
    expect(query.data.value, [1, 2]);

    // Fetch next -> [2, 3]
    await query.fetchNextPage();
    expect(query.data.value, [2, 3]);

    // Fetch previous -> should fetch 1 and prepend. Length becomes 3, so last page drops -> [1, 2]
    await query.fetchPreviousPage();
    expect(query.data.value, [1, 2]);

    // Fetch previous again -> [0, 1]
    await query.fetchPreviousPage();
    expect(query.data.value, [0, 1]);
    
    query.dispose();
  });
}
