import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/xtream_media_data_source.dart';
import '../../data/repositories/xtream_media_repository.dart';
import '../../domain/repositories/media_repository.dart';
import '../../models.dart';
import '../../xtream_service.dart';

/// Account-scoped service provider. Credentials remain in the existing
/// secure-storage-backed Store and are never copied into provider state.
final xtreamServiceProvider =
    Provider.family<XtreamService, Account>((ref, account) {
  return XtreamService.fromAccount(account);
});

/// Domain-facing repository provider used by feature controllers.
final mediaRepositoryProvider =
    Provider.family<MediaRepository, Account>((ref, account) {
  final service = ref.watch(xtreamServiceProvider(account));
  return XtreamMediaRepository(XtreamMediaDataSource(service));
});

final liveCategoriesProvider =
    FutureProvider.family<List<Category>, Account>((ref, account) {
  return ref.watch(mediaRepositoryProvider(account)).liveCategories();
});

final vodCategoriesProvider =
    FutureProvider.family<List<Category>, Account>((ref, account) {
  return ref.watch(mediaRepositoryProvider(account)).vodCategories();
});

final seriesCategoriesProvider =
    FutureProvider.family<List<Category>, Account>((ref, account) {
  return ref.watch(mediaRepositoryProvider(account)).seriesCategories();
});

/// Stable request object for legacy grid screens while they migrate to
/// repository-backed providers. Identity semantics keep unrelated screens
/// and subscriptions isolated.
class MediaGridLoadRequest {
  final Future<List<Category>> Function() loadCategories;
  final Future<List<MediaItem>> Function(String categoryId) loadItems;

  const MediaGridLoadRequest({
    required this.loadCategories,
    required this.loadItems,
  });
}

typedef MediaGridItemsKey = ({
  MediaGridLoadRequest loader,
  String categoryId,
});

final mediaGridCategoriesProvider =
    FutureProvider.autoDispose.family<List<Category>, MediaGridLoadRequest>(
  (ref, request) => request.loadCategories(),
);

final mediaGridItemsProvider =
    FutureProvider.autoDispose.family<List<MediaItem>, MediaGridItemsKey>(
  (ref, key) => key.loader.loadItems(key.categoryId),
);

/// Ephemeral UI search state; it is released when the grid screen leaves.
final mediaGridSearchQueryProvider =
    StateProvider.autoDispose.family<String, MediaGridLoadRequest>(
  (ref, request) => '',
);
