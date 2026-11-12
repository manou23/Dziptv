/// Central cache limits shared by catalogue and EPG data sources.
abstract final class CachePolicy {
  /// Live/VOD/series category and stream responses.
  static const Duration catalogTtl = Duration(minutes: 5);

  /// Short EPG is refreshed more often than the catalogue.
  static const Duration epgTtl = Duration(seconds: 90);

  /// Hard process-memory bound for cached responses.
  static const int maxEntries = 30;

  /// Opportunistic cleanup runs while the app process is alive.
  static const Duration maintenanceInterval = Duration(minutes: 10);
}
