import 'package:flutter_test/flutter_test.dart';
import 'package:mesut_iptv/app_info.dart';

void main() {
  group('compareAppVersions', () {
    test('recognizes a newer major release', () {
      expect(compareAppVersions('8.0.0', '7.3.0'), 1);
    });

    test('recognizes an older remote release', () {
      expect(compareAppVersions('7.3.0', '8.0.0'), -1);
    });

    test('compares patch versions', () {
      expect(compareAppVersions('8.0.1', '8.0.0'), 1);
      expect(compareAppVersions('8.0.0', '8.0.0'), 0);
    });

    test('treats missing trailing components as zero', () {
      expect(compareAppVersions('8.0', '8.0.0'), 0);
    });
  });
}
