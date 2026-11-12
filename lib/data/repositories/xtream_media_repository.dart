import '../../domain/repositories/media_repository.dart';
import '../../models.dart';
import '../datasources/xtream_media_data_source.dart';

/// Repository implementation that adapts the Xtream remote source to Domain.
class XtreamMediaRepository implements MediaRepository {
  final XtreamMediaDataSource remote;

  const XtreamMediaRepository(this.remote);

  @override
  Future<List<Category>> liveCategories() => remote.liveCategories();
  @override
  Future<List<Category>> vodCategories() => remote.vodCategories();
  @override
  Future<List<Category>> seriesCategories() => remote.seriesCategories();

  @override
  Future<List<MediaItem>> liveStreams(String categoryId) =>
      remote.liveStreams(categoryId);
  @override
  Future<List<MediaItem>> vodStreams(String categoryId) =>
      remote.vodStreams(categoryId);
  @override
  Future<List<MediaItem>> seriesList(String categoryId) =>
      remote.seriesList(categoryId);

  @override
  Future<List<MediaItem>> allLive() => remote.allLive();
  @override
  Future<List<MediaItem>> allVod() => remote.allVod();
  @override
  Future<List<MediaItem>> allSeries() => remote.allSeries();

  @override
  Future<List<Epg>> shortEpg(String streamId, {int limit = 3}) =>
      remote.shortEpg(streamId, limit: limit);

  @override
  String liveUrl(String streamId, {String? format}) =>
      remote.liveUrl(streamId, format: format);
}
