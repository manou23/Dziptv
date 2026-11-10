import 'package:flutter_test/flutter_test.dart';
import 'package:mesut_iptv/utils.dart';

void main() {
  group('isAdult', () {
    test('detects common adult category labels', () {
      expect(isAdult('XXX Movies'), isTrue);
      expect(isAdult('Adult Channels'), isTrue);
      expect(isAdult('18+'), isTrue);
      expect(isAdult('قنوات للكبار'), isTrue);
    });

    test('does not classify ordinary family categories as adult', () {
      expect(isAdult('Family Movies'), isFalse);
      expect(isAdult('Kids Cartoons'), isFalse);
      expect(isAdult('Sports'), isFalse);
    });
  });
}
