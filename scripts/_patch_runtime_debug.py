from pathlib import Path

root = Path('.')

# home_screen.dart
p = root / 'lib/screens/home_screen.dart'
s = p.read_text(encoding='utf-8')
s = s.replace("import 'photo_preview_screen.dart';\n", "import 'debug_info_screen.dart';\nimport 'photo_preview_screen.dart';\n", 1)
old = '''  void _showAbout() {\n    final disclaimer = AppLocalizations.of(context)?.trademarkDisclaimer ??\n        'Olympus and OM System are trademarks of their respective owners. '\n            'This is an unofficial app, not affiliated with or endorsed by '\n            'OM Digital Solutions.';\n    showAboutDialog(\n      context: context,\n      applicationName: appName,\n      applicationVersion: 'v$appVersion (build $appBuild)',\n'''
new = '''  void _openDebugInfo() {\n    unawaited(\n      Navigator.of(context).push<void>(\n        MaterialPageRoute<void>(builder: (_) => const DebugInfoScreen()),\n      ),\n    );\n  }\n\n  Future<void> _showAbout() async {\n    final installedVersion = await AppUpdateService.getInstalledVersion();\n    if (!mounted) return;\n    final disclaimer = AppLocalizations.of(context)?.trademarkDisclaimer ??\n        'Olympus and OM System are trademarks of their respective owners. '\n            'This is an unofficial app, not affiliated with or endorsed by '\n            'OM Digital Solutions.';\n    showAboutDialog(\n      context: context,\n      applicationName: appName,\n      applicationVersion: installedVersion.display,\n'''
if old not in s:
    raise SystemExit('home about start marker not found')
s = s.replace(old, new, 1)
old = '''        const Text(\n          'Changelog v$appVersion:',\n          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),\n        ),\n'''
new = '''        Text(\n          'Changelog v${installedVersion.versionName}:',\n          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),\n        ),\n'''
if old not in s:
    raise SystemExit('home changelog marker not found')
s = s.replace(old, new, 1)
old = '''            IconButton(\n              icon: const Icon(Icons.info_outline),\n              tooltip: 'About',\n              onPressed: _showAbout,\n            ),\n'''
new = '''            GestureDetector(\n              behavior: HitTestBehavior.opaque,\n              onLongPress: _openDebugInfo,\n              child: IconButton(\n                icon: const Icon(Icons.info_outline),\n                tooltip: 'About · hold for diagnostics',\n                onPressed: _showAbout,\n              ),\n            ),\n'''
if old not in s:
    raise SystemExit('home info button marker not found')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')

# Version bump.
p = root / 'lib/version.dart'
s = p.read_text(encoding='utf-8').replace("const String appBuild = '10';", "const String appBuild = '11';")
p.write_text(s, encoding='utf-8')
p = root / 'pubspec.yaml'
s = p.read_text(encoding='utf-8').replace('version: 1.3.4+10', 'version: 1.3.4+11')
p.write_text(s, encoding='utf-8')

# Deterministic local release: explicit cache removal and same non-obfuscated AOT mode as CI.
p = root / 'build_release.cmd'
s = p.read_text(encoding='utf-8')
old = '''call "%FLUTTER%" clean\nif errorlevel 1 goto :failed\n\necho.\necho [2/7] Resolving dependencies...\n'''
new = '''call "%FLUTTER%" clean\nif errorlevel 1 goto :failed\n\nrem Be explicit on Windows: stale .dart_tool/flutter_build or Android project\nrem caches must not survive a release build even if a tool leaves them behind.\ncall "%PROJECT%\\android\\gradlew.bat" --stop >nul 2>nul\nif exist "%PROJECT%\\build" rmdir /S /Q "%PROJECT%\\build"\nif exist "%PROJECT%\\.dart_tool" rmdir /S /Q "%PROJECT%\\.dart_tool"\nif exist "%PROJECT%\\android\\.gradle" rmdir /S /Q "%PROJECT%\\android\\.gradle"\nif exist "%PROJECT%\\build" (\n  echo ERROR: build directory could not be removed.\n  goto :failed\n)\nif exist "%PROJECT%\\.dart_tool" (\n  echo ERROR: .dart_tool directory could not be removed.\n  goto :failed\n)\n\necho.\necho [2/7] Resolving dependencies...\n'''
if old not in s:
    raise SystemExit('build clean marker not found')
s = s.replace(old, new, 1)
s = s.replace(' --obfuscate --split-debug-info=build/symbols', '', 1)
s = s.replace('echo Symbols: %PROJECT%\\build\\symbols\n', '')
p.write_text(s, encoding='utf-8')

# Strict AOT verifier again: local and CI release modes are now the same.
p = root / 'scripts/verify_apk_dart_metadata.ps1'
s = p.read_text(encoding='utf-8')
start = s.index('$commitBytes =')
prefix = s[:start]
suffix = '''$commitBytes = [System.Text.Encoding]::UTF8.GetBytes($ExpectedCommit)\n$timeBytes = [System.Text.Encoding]::UTF8.GetBytes($ExpectedBuildTime)\n\nif (-not (Test-ByteSequence -Haystack $bytes -Needle $commitBytes)) {\n    throw "Dart AOT metadata does not contain current Git commit '$ExpectedCommit'. Refusing a stale or inconsistent APK."\n}\nif (-not (Test-ByteSequence -Haystack $bytes -Needle $timeBytes)) {\n    throw "Dart AOT metadata does not contain current build time '$ExpectedBuildTime'. Refusing a stale or inconsistent APK."\n}\n\nWrite-Host "[verify] Dart AOT metadata matches commit $ExpectedCommit and build time $ExpectedBuildTime"\n'''
p.write_text(prefix + suffix, encoding='utf-8')

# Four-finger tests for immediate trigger.
p = root / 'test/four_finger_debug_trigger_test.dart'
p.write_text('''import 'package:flutter/material.dart';\nimport 'package:flutter_test/flutter_test.dart';\nimport 'package:olympus_tg6_manager/widgets/four_finger_debug_trigger.dart';\n\nvoid main() {\n  testWidgets('four simultaneous pointers trigger diagnostics once', (tester) async {\n    var triggerCount = 0;\n    await tester.pumpWidget(\n      MaterialApp(\n        home: FourFingerDebugTrigger(\n          onTriggered: () => triggerCount++,\n          child: const SizedBox.expand(),\n        ),\n      ),\n    );\n\n    final gestures = <TestGesture>[];\n    for (var pointer = 1; pointer <= 4; pointer++) {\n      gestures.add(\n        await tester.startGesture(\n          Offset(30.0 * pointer, 80),\n          pointer: pointer,\n        ),\n      );\n    }\n    await tester.pump();\n    expect(triggerCount, 1);\n\n    for (final gesture in gestures) {\n      await gesture.up();\n    }\n  });\n\n  testWidgets('three pointers do not trigger diagnostics', (tester) async {\n    var triggerCount = 0;\n    await tester.pumpWidget(\n      MaterialApp(\n        home: FourFingerDebugTrigger(\n          onTriggered: () => triggerCount++,\n          child: const SizedBox.expand(),\n        ),\n      ),\n    );\n\n    final gestures = <TestGesture>[];\n    for (var pointer = 1; pointer <= 3; pointer++) {\n      gestures.add(\n        await tester.startGesture(\n          Offset(30.0 * pointer, 80),\n          pointer: pointer,\n        ),\n      );\n    }\n    await tester.pump();\n    expect(triggerCount, 0);\n\n    for (final gesture in gestures) {\n      await gesture.up();\n    }\n  });\n}\n''', encoding='utf-8')

# Changelog note.
p = root / 'CHANGELOG.md'
s = p.read_text(encoding='utf-8')
needle = '### Changed\n'
insert = ('### Changed\n'
          '- About now reads the installed Android package version/build at runtime instead of displaying a duplicated Dart constant.\n'
          '- Four-finger diagnostics opens immediately on the fourth touch; long-pressing the About icon is a fallback diagnostics entry point.\n'
          '- Local release builds explicitly remove Flutter/Android project caches and use the same non-obfuscated Dart AOT mode as CI so stale `libapp.so` is rejected by strict build metadata verification.\n'
          '- Diagnostic test build bumped to **1.3.4+11**.\n')
if needle not in s:
    raise SystemExit('changelog marker not found')
s = s.replace(needle, insert, 1)
p.write_text(s, encoding='utf-8')
