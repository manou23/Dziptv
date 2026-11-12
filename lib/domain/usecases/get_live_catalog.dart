import '../../models.dart';
import '../repositories/media_repository.dart';

/// Use case for loading the live-TV catalogue for one category.
class GetLiveCatalog {
  final MediaRepository repository;

  const GetLiveCatalog(this.repository);

  Future<List<MediaItem>> call(String categoryId) =>
      repository.liveStreams(categoryId);
}
