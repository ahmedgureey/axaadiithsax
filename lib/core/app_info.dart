/// App identity and version.
///
/// The version mirrors `version:` in pubspec.yaml (a unit test fails if they
/// drift), so the About screen never shows an invented number and no extra
/// package is needed to read it at runtime.
abstract final class AppInfo {
  static const name = 'Xadiith App';
  static const tagline = 'Axaadiista Nabiga ﷺ';

  /// `version` part of pubspec `version: 1.0.9+10`.
  static const version = '1.0.9';

  /// Build number part of pubspec `version: 1.0.9+10`.
  static const buildNumber = '10';

  static const pubspecVersion = '$version+$buildNumber';
}
