const String kAppName = 'Mesut IPTV';
const String kBrand = 'Mesut23';
const String kVersion = '8.0.0';

/// قناة الدعم الرسمية للمشروع.
const String kContactEmail = 'mesut.amari23@gmail.com';
const String kContactUrl = 'https://github.com/manou23/Dziptv/issues';

/// مستودع GitHub لفحص التحديثات، مثال: 'user/repo'. فارغ = معطّل
const String kUpdateRepo = 'manou23/Dziptv';
const String kBuildCommit = String.fromEnvironment('MESUT_BUILD_COMMIT', defaultValue: 'unknown');

/// Compares semantic app versions (major.minor.patch).
/// Returns -1 when [left] is older, 1 when newer, and 0 when equal.
int compareAppVersions(String left, String right) {
  final leftParts = RegExp(r'\d+')
      .allMatches(left)
      .map((match) => int.parse(match.group(0)!))
      .toList();
  final rightParts = RegExp(r'\d+')
      .allMatches(right)
      .map((match) => int.parse(match.group(0)!))
      .toList();
  for (var i = 0; i < 3; i++) {
    final l = i < leftParts.length ? leftParts[i] : 0;
    final r = i < rightParts.length ? rightParts[i] : 0;
    if (l != r) return l < r ? -1 : 1;
  }
  return 0;
}
