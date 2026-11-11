import 'package:flutter_test/flutter_test.dart';
import 'package:mesut_iptv/xtream_service.dart';

void main() {
  group('XtreamService.liveUrl', () {
    final service = XtreamService(
      'https://provider.example/',
      'user name',
      'p/a:ss',
    );

    test('builds an M3U8 URL when explicitly requested', () {
      expect(
        service.liveUrl('123', format: 'm3u8'),
        'https://provider.example/live/user%20name/p%2Fa%3Ass/123.m3u8',
      );
    });

    test('builds a TS URL when explicitly requested', () {
      expect(
        service.liveUrl('456', format: 'ts'),
        'https://provider.example/live/user%20name/p%2Fa%3Ass/456.ts',
      );
    });

    test('normalizes unsupported format values to TS', () {
      expect(
        service.liveUrl('789', format: 'hls'),
        'https://provider.example/live/user%20name/p%2Fa%3Ass/789.ts',
      );
    });

    test('preserves a provider base path', () {
      final withPath = XtreamService(
        'https://provider.example/iptv/',
        'demo',
        'secret',
      );

      expect(
        withPath.liveUrl('42', format: 'm3u8'),
        'https://provider.example/iptv/live/demo/secret/42.m3u8',
      );
    });
  });
}
