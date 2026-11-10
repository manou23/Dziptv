/// Build-time target selector. The TV APK is compiled with MESUT_TARGET=tv.
const bool kIsTvBuild = String.fromEnvironment('MESUT_TARGET') == 'tv';
