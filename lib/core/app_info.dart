/// App identity and version.
///
/// The version mirrors `version:` in pubspec.yaml (a unit test fails if they
/// drift), so the About screen never shows an invented number and no extra
/// package is needed to read it at runtime.
///
/// Update APK (`apk/Xadiith-App.apk`, linked from update.json): build it as a
/// universal APK with `--build-number=<3000 + buildNumber>` so its Android
/// versionCode is above every split APK (arm64 = 2000+N, armv7 = 1000+N) and
/// installs over any earlier build. The update check uses [buildNumber].
abstract final class AppInfo {
  static const name = 'Xadiith App';
  static const tagline = 'Axaadiista Nabiga ﷺ';

  /// `version` part of pubspec `version: 1.0.11+12`.
  static const version = '1.0.11';

  /// Build number part of pubspec `version: 1.0.11+12`.
  static const buildNumber = '12';

  static const pubspecVersion = '$version+$buildNumber';
}
