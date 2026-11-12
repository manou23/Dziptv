import '../../models.dart';

/// Domain contract for media catalogue and programme-guide access.
abstract interface class MediaRepository {
  Future<List<Category>> liveCategories();
  Future<List<Category>> vodCategories();
  Future<List<Category>> seriesCategories();

  Future<List<MediaItem>> liveStreams(String categoryId);
  Future<List<MediaItem>> vodStreams(String categoryId);
  Future<List<MediaItem>> seriesList(String categoryId);

  Future<List<MediaItem>> allLive();
  Future<List<MediaItem>> allVod();
  Future<List<MediaItem>> allSeries();

  Future<List<Epg>> shortEpg(String streamId, {int limit = 3});
  String liveUrl(String streamId, {String? format});
  Future<Map<String, String>> vodInfo(String vodId);
  Future<Map<int, List<Episode>>> seriesEpisodes(String seriesId);
  String movieUrl(String vodId, String extension);
  String episodeUrl(String episodeId, String extension);
}
