import 'package:flutter/material.dart';
import 'package:zenify/zenify.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class InfiniteQueryController extends ZenController {
  late final ZenInfiniteQuery<PaginatedResponse<Post>> infiniteQuery;
  late final ScrollController scrollController;

  @override
  void onInit() {
    super.onInit();

    // Create infinite query
    infiniteQuery = ZenInfiniteQuery<PaginatedResponse<Post>>(
      queryKey: 'posts:infinite',
      infiniteFetcher: (pageParam, cancelToken) async {
        final page = pageParam as int? ?? 1;
        return await ApiService.getPosts(
          page: page,
          pageSize: 10,
          cancelToken: cancelToken,
        );
      },
      getNextPageParam: (lastPage, allPages) {
        // Return next page number if there are more pages
        return lastPage.hasMore ? lastPage.page + 1 : null;
      },
      initialPageParam: 1,
      config: const ZenQueryConfig(
        staleTime: Duration(minutes: 5),
      ),
    );

    // Setup scroll controller for infinite scroll
    scrollController = ScrollController();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      // Load more when user is 200px from bottom
      if (infiniteQuery.hasNextPage.value &&
          !infiniteQuery.isFetchingNextPage.value) {
        infiniteQuery.fetchNextPage();
      }
    }
  }

  void loadMore() {
    infiniteQuery.fetchNextPage();
  }

  @override
  void onClose() {
    scrollController.dispose();
    infiniteQuery.dispose();
    super.onClose();
  }
}
