import 'package:flutter_test/flutter_test.dart';
import '../lib/utils.dart';

void main() {
  group('adult content classifier', () {
    test('blocks common English adult labels and brands', () {
      for (final value in [
        'XXX Movies', 'Adult Channels', 'Porn Hub', 'Hentai 18+',
        'OnlyFans', 'Brazzers HD', 'XVideos', 'Explicit Uncensored',
      ]) {
        expect(isAdult(value), isTrue, reason: value);
      }
    });

    test('blocks Arabic adult labels', () {
      for (final value in [
        'قنوات إباحية', 'أفلام للكبار فقط', 'محتوى جنسي', 'عري وتعري',
        'بورن', 'سكس',
      ]) {
        expect(isAdult(value), isTrue, reason: value);
      }
    });

    test('keeps ordinary entertainment titles visible', () {
      for (final value in [
        'Action Movies HD', 'National Geographic', 'Family TV',
      ]) {
        expect(isAdult(value), isFalse, reason: value);
      }
    });
  });
}
