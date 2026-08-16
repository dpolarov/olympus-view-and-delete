/// Build metadata injected by release/CI commands with `--dart-define`.
///
/// These values are diagnostic only. Android package versionName/versionCode
/// remain the source of truth for the installed application version.
const String buildTimeUtc = String.fromEnvironment(
  'OLYMPUS_BUILD_TIME_UTC',
  defaultValue: 'not embedded',
);

const String buildGitCommit = String.fromEnvironment(
  'OLYMPUS_GIT_COMMIT',
  defaultValue: 'not embedded',
);

const String buildFlutterVersion = String.fromEnvironment(
  'OLYMPUS_FLUTTER_VERSION',
  defaultValue: 'not embedded',
);
