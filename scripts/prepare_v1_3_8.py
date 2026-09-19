from pathlib import Path


def replace_once(path, old, new):
    p = Path(path)
    s = p.read_text(encoding='utf-8')
    if old not in s:
        raise SystemExit(f'Expected text not found in {path}: {old[:80]!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8')


replace_once('pubspec.yaml', 'version: 1.3.7+16', 'version: 1.3.8+17')
replace_once(
    'lib/version.dart',
    "const String appVersion = '1.3.7';\nconst String appBuild = '16';",
    "const String appVersion = '1.3.8';\nconst String appBuild = '17';",
)

changelog = Path('CHANGELOG.md')
s = changelog.read_text(encoding='utf-8')
section = """## [1.3.8] - 2026-09-19

### Fixed
- **Android RAW downloads to DCIM**: Olympus `.ORF`, Adobe `.DNG`, and generic `.RAW` files are now stored through `MediaStore.Images` instead of `MediaStore.Files`, allowing Android 10+ to save them into `DCIM/OlympusView` just like JPEG files.
- The same RAW MediaStore routing is used by both foreground and background downloads.
- A RAW file is marked as downloaded only after the save completes successfully, so the existing green downloaded marker stays consistent with files actually written to the device.

### Changed
- Version set to **1.3.8+17**.
- This is a normal in-app update for users already on **1.3.6 or newer** and uses the existing permanent production signing identity.

"""
marker = '# Changelog\n\n'
if '## [1.3.8]' not in s:
    if marker not in s:
        raise SystemExit('CHANGELOG marker not found')
    changelog.write_text(s.replace(marker, marker + section, 1), encoding='utf-8')

agents = Path('AGENTS.md')
s = agents.read_text(encoding='utf-8')
rule = """

## Release Process

For **every release**, updating release metadata is mandatory and must be part of the same release change:
- Bump the application version/build in `pubspec.yaml` and `lib/version.dart`.
- Add the new release section to `CHANGELOG.md`.
- Update the public website release information and changelog in `docs/index.html`, `docs/index.md`, `docs/index.ru.md`, and `docs/index.uk.md`.
- Update `docs/llms.txt` so its current stable version and release summary match the new release.
- Keep historical release entries intact; add a new latest entry instead of rewriting old release history.
- Before publishing, verify that the GitHub Release notes, `CHANGELOG.md`, and website describe the same version and changes.
"""
if '## Release Process' not in s:
    agents.write_text(s.rstrip() + rule + '\n', encoding='utf-8')

md = Path('docs/index.md')
s = md.read_text(encoding='utf-8')
s = s.replace(
    '**Current Android release:** v1.3.7+16 — August 27, 2026  ',
    '**Current Android release:** v1.3.8+17 — September 19, 2026  ',
    1,
)
new = """## v1.3.8 highlights

- Fixed Android downloads of Olympus **ORF** RAW files to `DCIM/OlympusView`.
- ORF, DNG and RAW files now use the Android image MediaStore collection, matching the JPEG save path and avoiding the `Primary directory DCIM not allowed` error.
- Foreground and background RAW downloads use the same corrected storage path.
- Successful RAW downloads receive the same persistent green downloaded marker as JPEG files.
- Users on **v1.3.6 or newer** can update normally through the built-in updater.
- Version: **1.3.8+17**.

"""
if '## v1.3.8 highlights' not in s:
    if '## v1.3.7 highlights\n' not in s:
        raise SystemExit('English markdown release marker not found')
    s = s.replace('## v1.3.7 highlights\n', new + '## v1.3.7 highlights\n', 1)
md.write_text(s, encoding='utf-8')

md = Path('docs/index.ru.md')
s = md.read_text(encoding='utf-8')
s = s.replace(
    '**Текущая Android-версия:** v1.3.7+16 — 27 августа 2026  ',
    '**Текущая Android-версия:** v1.3.8+17 — 19 сентября 2026  ',
    1,
)
new = """## Что нового в v1.3.8

- Исправлено скачивание RAW-файлов Olympus **ORF** в `DCIM/OlympusView` на Android.
- ORF, DNG и RAW теперь сохраняются через коллекцию изображений Android MediaStore, как JPEG, поэтому ошибка `Primary directory DCIM not allowed` больше не возникает.
- Исправление действует и для обычной, и для фоновой загрузки.
- После успешного сохранения RAW получает ту же постоянную зелёную метку скачанного файла, что и JPEG.
- Пользователи **v1.3.6 и новее** могут обновиться штатно через встроенный updater.
- Версия **1.3.8+17**.

"""
if '## Что нового в v1.3.8' not in s:
    if '## Что нового в v1.3.7\n' not in s:
        raise SystemExit('Russian markdown release marker not found')
    s = s.replace('## Что нового в v1.3.7\n', new + '## Что нового в v1.3.7\n', 1)
md.write_text(s, encoding='utf-8')

md = Path('docs/index.uk.md')
s = md.read_text(encoding='utf-8')
s = s.replace(
    '**Поточна Android-версія:** v1.3.7+16 — 27 серпня 2026  ',
    '**Поточна Android-версія:** v1.3.8+17 — 19 вересня 2026  ',
    1,
)
new = """## Що нового у v1.3.8

- Виправлено завантаження RAW-файлів Olympus **ORF** до `DCIM/OlympusView` на Android.
- ORF, DNG і RAW тепер зберігаються через колекцію зображень Android MediaStore, як JPEG, тому помилка `Primary directory DCIM not allowed` більше не виникає.
- Виправлення діє і для звичайного, і для фонового завантаження.
- Після успішного збереження RAW отримує ту саму постійну зелену позначку завантаженого файлу, що й JPEG.
- Користувачі **v1.3.6 і новіше** можуть оновитися штатно через вбудований updater.
- Версія **1.3.8+17**.

"""
if '## Що нового у v1.3.8' not in s:
    if '## Що нового у v1.3.7\n' not in s:
        raise SystemExit('Ukrainian markdown release marker not found')
    s = s.replace('## Що нового у v1.3.7\n', new + '## Що нового у v1.3.7\n', 1)
md.write_text(s, encoding='utf-8')

llms = Path('docs/llms.txt')
s = llms.read_text(encoding='utf-8')
s = s.replace(
    'Current stable Android release: **v1.3.7 (build 16), released August 27, 2026**.',
    'Current stable Android release: **v1.3.8 (build 17), released September 19, 2026**.',
    1,
)
old = 'Release v1.3.7 improves camera-transfer reliability: thumbnail disk-cache lookup now completes before consuming camera network slots, full-screen preview cache stays bounded during rapid paging, non-200 download responses are rejected, and failed or truncated transfers are prevented from poisoning persistent caches. New Android integration tests exercise a fake Olympus camera over real TCP sockets and verify failure paths, filesystem cache persistence, and thumbnail concurrency.'
new = 'Release v1.3.8 fixes Android RAW storage: Olympus ORF, Adobe DNG, and generic RAW files now save to DCIM/OlympusView through MediaStore.Images in both foreground and background downloads. This avoids Android scoped-storage rejection of DCIM for generic MediaStore files and restores the normal persistent green downloaded marker after a successful RAW save.'
if old not in s:
    raise SystemExit('llms release summary not found')
llms.write_text(s.replace(old, new, 1), encoding='utf-8')

html = Path('docs/index.html')
s = html.read_text(encoding='utf-8')
for old, new in [
    ('"softwareVersion": "1.3.7"', '"softwareVersion": "1.3.8"'),
    ('"dateModified": "2026-08-27"', '"dateModified": "2026-09-19"'),
    ('releases/tag/v1.3.7', 'releases/tag/v1.3.8'),
]:
    if old not in s:
        raise SystemExit(f'HTML metadata marker not found: {old}')
    s = s.replace(old, new, 1)


def insert_html(marker, unique, block):
    global s
    if unique not in s:
        if marker not in s:
            raise SystemExit(f'HTML changelog marker not found: {marker}')
        s = s.replace(marker, marker + block, 1)


insert_html(
    '    <h2 id="changelog-en">Changelog</h2>\n    <div class="changelog">\n',
    'v1.3.8 — September 19, 2026',
    """        <div class="changelog-version">
            <h3>v1.3.8 — September 19, 2026</h3>
            <h4>Android RAW download hotfix</h4>
            <ul>
                <li><strong>ORF/DNG/RAW downloads fixed on Android</strong> — RAW files now use MediaStore.Images and can be saved to DCIM/OlympusView like JPEG files.</li>
                <li>The fix applies to both foreground and background downloads.</li>
                <li>Successful RAW downloads now receive the normal persistent green downloaded marker.</li>
                <li>Users on v1.3.6 or newer can update normally through the built-in updater.</li>
                <li>Version: <strong>1.3.8+17</strong>.</li>
            </ul>
        </div>
""",
)
insert_html(
    '    <h2 id="changelog-uk">Журнал змін</h2>\n    <div class="changelog">\n',
    'v1.3.8 — 19 вересня 2026',
    """        <div class="changelog-version">
            <h3>v1.3.8 — 19 вересня 2026</h3>
            <h4>Виправлення завантаження RAW на Android</h4>
            <ul>
                <li><strong>Виправлено завантаження ORF/DNG/RAW</strong> — RAW-файли тепер використовують MediaStore.Images і можуть зберігатися в DCIM/OlympusView як JPEG.</li>
                <li>Виправлення діє для звичайного та фонового завантаження.</li>
                <li>Після успішного збереження RAW отримує звичайну постійну зелену позначку завантаженого файлу.</li>
                <li>Користувачі v1.3.6 і новіше можуть оновитися штатно через вбудований updater.</li>
                <li>Версія: <strong>1.3.8+17</strong>.</li>
            </ul>
        </div>
""",
)
insert_html(
    '    <h2 id="changelog-ru">Журнал изменений</h2>\n    <div class="changelog">\n',
    'v1.3.8 — 19 сентября 2026',
    """        <div class="changelog-version">
            <h3>v1.3.8 — 19 сентября 2026</h3>
            <h4>Исправление загрузки RAW на Android</h4>
            <ul>
                <li><strong>Исправлено скачивание ORF/DNG/RAW</strong> — RAW-файлы теперь используют MediaStore.Images и могут сохраняться в DCIM/OlympusView как JPEG.</li>
                <li>Исправление действует для обычной и фоновой загрузки.</li>
                <li>После успешного сохранения RAW получает обычную постоянную зелёную метку скачанного файла.</li>
                <li>Пользователи v1.3.6 и новее могут обновиться штатно через встроенный updater.</li>
                <li>Версия: <strong>1.3.8+17</strong>.</li>
            </ul>
        </div>
""",
)
html.write_text(s, encoding='utf-8')

Path('.github/workflows/prepare-v1.3.8.yml').unlink()
Path('scripts/prepare_v1_3_8.py').unlink()
