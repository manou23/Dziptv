import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mesut_iptv/core/cache/cache_policy.dart';
import 'package:mesut_iptv/core/errors/app_error_mapper.dart';
import 'package:mesut_iptv/domain/repositories/media_repository.dart';
import 'package:mesut_iptv/domain/usecases/get_live_catalog.dart';
import 'package:mesut_iptv/models.dart';

class _FakeMediaRepository implements MediaRepository {
  _FakeMediaRepository(this.items);

  final List<MediaItem> items;
  String? requestedCategory;

  @override
  Future<List<MediaItem>> liveStreams(String categoryId) async {
    requestedCategory = categoryId;
    return items;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CachePolicy', () {
    test('keeps EPG cache shorter than catalogue cache', () {
      expect(CachePolicy.epgTtl, lessThan(CachePolicy.catalogTtl));
      expect(CachePolicy.maxEntries, greaterThan(0));
      expect(CachePolicy.maintenanceInterval, isNotNull);
    });
  });

  group('AppErrorMapper', () {
    test('maps timeouts to an actionable message', () {
      expect(
        AppErrorMapper.toUserMessage(
          TimeoutException('raw timeout'),
          fallback: 'fallback',
        ),
        contains('مهلة الاتصال'),
      );
    });

    test('does not expose network exception details', () {
      final message = AppErrorMapper.toUserMessage(
        const SocketException('failed for https://user:secret@example.test'),
        fallback: 'fallback',
      );
      expect(message, contains('تعذر الاتصال'));
      expect(message, isNot(contains('secret')));
      expect(message, isNot(contains('example.test')));
    });
  });

  test('GetLiveCatalog delegates to the repository', () async {
    final items = [MediaItem('1', 'Demo channel', '', '')];
    final repository = _FakeMediaRepository(items);
    final useCase = GetLiveCatalog(repository);

    final result = await useCase('sports');

    expect(repository.requestedCategory, 'sports');
    expect(result, items);
  });
}
