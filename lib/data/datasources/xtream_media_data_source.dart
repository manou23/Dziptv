import '../../models.dart';
import '../../xtream_service.dart';

/// Remote data source. Xtream protocol details stay outside presentation.
class XtreamMediaDataSource {
  final XtreamService service;

  const XtreamMediaDataSource(this.service);

  Future<List<Category>> liveCategories() => service.liveCategories();
  Future<List<Category>> vodCategories() => service.vodCategories();
  Future<List<Category>> seriesCategories() => service.seriesCategories();

  Future<List<MediaItem>> liveStreams(String id) => service.liveStreams(id);
  Future<List<MediaItem>> vodStreams(String id) => service.vodStreams(id);
  Future<List<MediaItem>> seriesList(String id) => service.seriesList(id);

  Future<List<MediaItem>> allLive() => service.allLive();
  Future<List<MediaItem>> allVod() => service.allVod();
  Future<List<MediaItem>> allSeries() => service.allSeries();

  Future<List<Epg>> shortEpg(String id, {int limit = 3}) =>
      service.shortEpg(id, limit: limit);
  String liveUrl(String id, {String? format}) =>
      service.liveUrl(id, format: format);
}
