from pathlib import Path

path = Path('lib/screens/home_screen.dart')
text = path.read_text(encoding='utf-8')

old = """        content: Text(_localizedText(
          en: 'Olympus View ${release.version} is available. Download it in the background?',
          ru: 'Доступна версия Olympus View ${release.version}. Скачать обновление в фоне?',
          uk: 'Доступна версія Olympus View ${release.version}. Завантажити оновлення у фоні?',
        )),
"""

new = """        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_localizedText(
                  en: 'Olympus View ${release.version} is available.',
                  ru: 'Доступна версия Olympus View ${release.version}.',
                  uk: 'Доступна версія Olympus View ${release.version}.',
                )),
                if (release.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    _localizedText(
                      en: \"What's new\",
                      ru: 'Что нового',
                      uk: 'Що нового',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    release.releaseNotes,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  _localizedText(
                    en: 'Download this update in the background?',
                    ru: 'Скачать это обновление в фоне?',
                    uk: 'Завантажити це оновлення у фоні?',
                  ),
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          ),
        ),
"""

if old not in text:
    raise SystemExit('Update dialog insertion point not found')

path.write_text(text.replace(old, new, 1), encoding='utf-8')
