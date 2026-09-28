import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class NewsPost {
  const NewsPost({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.imageUrl,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final bool pinned;
  final DateTime publishedAt;

  factory NewsPost.fromJson(Map<String, dynamic> j) => NewsPost(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    imageUrl: j['imageUrl'] as String?,
    pinned: j['pinned'] as bool? ?? false,
    publishedAt: DateTime.parse(j['publishedAt'] as String),
  );
}

class NewsPage {
  const NewsPage(this.items, this.nextBefore);

  final List<NewsPost> items;
  final String? nextBefore;
}

class NewsRepository {
  NewsRepository(this._get);

  final Future<Map<String, dynamic>> Function(String path, Map<String, dynamic>? query) _get;

  Future<NewsPage> page({String? before, int limit = 15}) async {
    final json = await _get('/news', {'limit': limit, 'before': ?before});
    return NewsPage(
      (json['items'] as List<dynamic>).map((e) => NewsPost.fromJson(e as Map<String, dynamic>)).toList(),
      json['nextBefore'] as String?,
    );
  }

  Future<NewsPost> byId(String id) async => NewsPost.fromJson(await _get('/news/$id', null));
}

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return NewsRepository((path, query) => api.get<Map<String, dynamic>>(path, query: query, auth: false));
});

class NewsFeedState {
  const NewsFeedState({this.items = const [], this.nextBefore, this.loadingMore = false});

  final List<NewsPost> items;
  final String? nextBefore;
  final bool loadingMore;

  bool get hasMore => nextBefore != null;
}

/// Лента новостей с подгрузкой по курсору.
final newsFeedProvider = AsyncNotifierProvider<NewsFeedController, NewsFeedState>(NewsFeedController.new);

class NewsFeedController extends AsyncNotifier<NewsFeedState> {
  @override
  Future<NewsFeedState> build() async {
    final page = await ref.read(newsRepositoryProvider).page();
    return NewsFeedState(items: page.items, nextBefore: page.nextBefore);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(NewsFeedState(items: current.items, nextBefore: current.nextBefore, loadingMore: true));
    try {
      final page = await ref.read(newsRepositoryProvider).page(before: current.nextBefore);
      state = AsyncData(NewsFeedState(items: [...current.items, ...page.items], nextBefore: page.nextBefore));
    } catch (_) {
      state = AsyncData(NewsFeedState(items: current.items, nextBefore: current.nextBefore));
    }
  }
}

/// Отдельная новость (для deeplink из push, когда её нет в загруженной ленте).
final newsPostProvider = FutureProvider.autoDispose.family<NewsPost, String>((ref, id) async {
  final cached = ref.read(newsFeedProvider).value?.items.where((p) => p.id == id).firstOrNull;
  if (cached != null) return cached;
  return ref.read(newsRepositoryProvider).byId(id);
});
