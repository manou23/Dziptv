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
