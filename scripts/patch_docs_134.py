from pathlib import Path

README = Path('README.md')
HTML = Path('docs/index.html')


def once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


def insert_before(text, marker, block, label):
    if text.count(marker) != 1:
        raise SystemExit(f'{label}: marker count={text.count(marker)}')
    return text.replace(marker, block + marker, 1)


readme = README.read_text(encoding='utf-8')

# README: new Android features in EN / UK / RU.
readme = once(readme,
    '- **Select and download groups of files** by date in one tap\n- **Show/hide RAW (ORF)** files to remove duplicates',
    '- **Select and download groups of files** by date in one tap\n- **Download in the background on Android** while the app is minimized or the screen is off\n- **Remember downloaded files** with persistent green markers across app restarts\n- **Show/hide RAW (ORF)** files to remove duplicates',
    'README EN advantages')
readme = once(readme,
    '- **Вибирати та завантажувати групи файлів** за датою одним натиском\n- **Показувати/приховувати RAW (ORF)** файли, щоб прибрати дублі',
    '- **Вибирати та завантажувати групи файлів** за датою одним натиском\n- **Завантажувати у фоні на Android** після згортання застосунку або вимкнення екрана\n- **Пам’ятати вже завантажені файли** та позначати їх зеленим між запусками\n- **Показувати/приховувати RAW (ORF)** файли, щоб прибрати дублі',
    'README UK advantages')
readme = once(readme,
    '- **Выбирать и скачивать группы файлов** по дате одним нажатием\n- **Показывать/скрывать RAW (ORF)** файлы, чтобы убрать дубли',
    '- **Выбирать и скачивать группы файлов** по дате одним нажатием\n- **Скачивать в фоне на Android** после сворачивания приложения или выключения экрана\n- **Помнить уже скачанные файлы** и отмечать их зелёным между запусками\n- **Показывать/скрывать RAW (ORF)** файлы, чтобы убрать дубли',
    'README RU advantages')

readme = once(readme,
    '### Download\n- Android: saves to `DCIM/OlympusView` — photos appear in gallery immediately',
    '### Download\n- Android: saves to `DCIM/OlympusView` — photos appear in gallery immediately\n- Android: optional **background download** continues while Olympus View is minimized or the screen is off\n- Android: successfully transferred files keep a persistent green **downloaded** marker',
    'README EN download')
readme = once(readme,
    "### Завантаження\n- На Android: збереження у `DCIM/OlympusView` — фото одразу з'являються у галереї",
    "### Завантаження\n- На Android: збереження у `DCIM/OlympusView` — фото одразу з'являються у галереї\n- На Android: опційне **фонове завантаження** продовжується після згортання застосунку або вимкнення екрана\n- На Android: успішно перенесені файли зберігають постійну зелену позначку **завантажено**",
    'README UK download')
readme = once(readme,
    '### Скачивание\n- На Android: сохранение в `DCIM/OlympusView` — фото сразу появляются в галерее',
    '### Скачивание\n- На Android: сохранение в `DCIM/OlympusView` — фото сразу появляются в галерее\n- На Android: опциональное **фоновое скачивание** продолжается после сворачивания приложения или выключения экрана\n- На Android: успешно перенесённые файлы сохраняют постоянную зелёную отметку **скачано**',
    'README RU download')

# Fix stale Android artifact name and stale generic build command.
readme = readme.replace('`releases/OlympusView.apk`', '`releases/OlympusView-Android.apk`')
readme = readme.replace('# Android APK\nflutter build apk --release', '# Android APK (GitHub / sideload flavor)\nflutter build apk --flavor github --release')

README.write_text(readme, encoding='utf-8')

html = HTML.read_text(encoding='utf-8')

# Metadata / structured data.
html = once(html,
    '<meta name="description" content="Free open-source app to manage Olympus and OM System cameras via WiFi. Delete photos directly from your camera, batch download by date, filter RAW files. Works on Android, Windows and browser. Best OI.Share alternative.">',
    '<meta name="description" content="Free open-source app to manage Olympus and OM System cameras via WiFi. Delete photos, background-download on Android, remember downloaded files, batch by date and filter RAW.">\n    <meta name="theme-color" content="#060d1b">',
    'meta description')
html = once(html,
    '"Batch download photos by date",\n        "RAW/ORF file filter",',
    '"Batch download photos by date",\n        "Background downloads on Android with completion notifications",\n        "Persistent markers for files already downloaded",\n        "RAW/ORF file filter",',
    'featureList')
html = html.replace('"dateModified": "2026-08-15",', '"dateModified": "2026-08-16",')

# Avoid stale version text next to a URL that always points to releases/latest.
html = html.replace('<p>v1.3.2 APK<br>Direct download</p>', '<p>Latest release APK<br>Direct download</p>')
html = html.replace('<p>v1.3.2 APK<br>Пряме завантаження</p>', '<p>Останній реліз APK<br>Пряме завантаження</p>')
html = html.replace('<p>v1.3.2 APK<br>Прямая загрузка</p>', '<p>Последний релиз APK<br>Прямая загрузка</p>')

# Advantage bullets.
html = insert_before(html,
    '            <li><strong>RAW/ORF filter</strong>',
    '            <li><strong>Background downloads on Android</strong> <span class="vs">— keep transferring with the app minimized or screen off</span></li>\n            <li><strong>Downloaded-file markers</strong> <span class="vs">— see what was already copied even after restarting</span></li>\n',
    'EN advantages')
html = insert_before(html,
    '            <li><strong>Фільтр RAW/ORF файлів</strong>',
    '            <li><strong>Фонове завантаження на Android</strong> <span class="vs">— працює після згортання застосунку або вимкнення екрана</span></li>\n            <li><strong>Позначки вже завантажених файлів</strong> <span class="vs">— видно навіть після перезапуску</span></li>\n',
    'UK advantages')
html = insert_before(html,
    '            <li><strong>Фильтр RAW/ORF файлов</strong>',
    '            <li><strong>Фоновое скачивание на Android</strong> <span class="vs">— работает после сворачивания приложения или выключения экрана</span></li>\n            <li><strong>Метки уже скачанных файлов</strong> <span class="vs">— видны даже после перезапуска</span></li>\n',
    'RU advantages')

# Feature cards, inserted before the existing multi-platform card in each language.
en_cards = '''        <div class="feature-card">
            <div class="feature-icon">⏬</div>
            <h3>Background Download</h3>
            <p>On Android, transfers keep running while Olympus View is minimized or the screen is off. Progress and completion are shown in system notifications.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon">✅</div>
            <h3>Already Downloaded</h3>
            <p>Successfully transferred files get a persistent green marker, so you can reconnect days later and immediately see what was already copied.</p>
        </div>
'''
uk_cards = '''        <div class="feature-card">
            <div class="feature-icon">⏬</div>
            <h3>Фонове завантаження</h3>
            <p>На Android передача продовжується після згортання Olympus View або вимкнення екрана. Прогрес і завершення показуються у системних сповіщеннях.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon">✅</div>
            <h3>Вже завантажено</h3>
            <p>Успішно перенесені файли отримують постійну зелену позначку, тому навіть через кілька днів видно, що вже було скопійовано.</p>
        </div>
'''
ru_cards = '''        <div class="feature-card">
            <div class="feature-icon">⏬</div>
            <h3>Фоновое скачивание</h3>
            <p>На Android передача продолжается после сворачивания Olympus View или выключения экрана. Прогресс и завершение показываются в системных уведомлениях.</p>
        </div>
        <div class="feature-card">
            <div class="feature-icon">✅</div>
            <h3>Уже скачано</h3>
            <p>Успешно перенесённые файлы получают постоянную зелёную отметку, поэтому даже через несколько дней видно, что уже было скопировано.</p>
        </div>
'''
html = insert_before(html, '        <div class="feature-card">\n            <div class="feature-icon">💻</div>\n            <h3>Multi-platform</h3>', en_cards, 'EN cards')
html = insert_before(html, '        <div class="feature-card">\n            <div class="feature-icon">💻</div>\n            <h3>Мультиплатформа</h3>', uk_cards, 'UK cards')
html = insert_before(html, '        <div class="feature-card">\n            <div class="feature-icon">💻</div>\n            <h3>Мультиплатформа</h3>', ru_cards, 'RU cards')

# How-to notes.
html = html.replace('<li>Use buttons for batch selection, download and deletion</li>', '<li>Use buttons for batch selection, download and deletion. On Android choose <strong>Background</strong> to keep transfers running outside the app; downloaded files stay marked in green.</li>')
html = html.replace('<li>Використовуйте кнопки для масового вибору, завантаження та видалення</li>', '<li>Використовуйте кнопки для масового вибору, завантаження та видалення. На Android виберіть <strong>У фоні</strong>; завантажені файли залишаються позначеними зеленим.</li>')
html = html.replace('<li>Используйте кнопки для массового выбора, скачивания и удаления</li>', '<li>Используйте кнопки для массового выбора, скачивания и удаления. На Android выберите <strong>В фоне</strong>; скачанные файлы остаются отмеченными зелёным.</li>')

# Upcoming changelog (do not claim it is already the public latest release).
en_log = '''        <div class="changelog-version">
            <h3>v1.3.4 — next release</h3>
            <h4>Android downloads &amp; gallery reliability</h4>
            <ul>
                <li><strong>Background downloads</strong> continue while the app is minimized or the screen is off, with progress and completion notifications</li>
                <li><strong>Persistent downloaded markers</strong> show files already transferred across app restarts</li>
                <li><strong>More reliable thumbnails and previews</strong> with JPEG completeness checks, retries and fallback loading</li>
            </ul>
        </div>
'''
uk_log = '''        <div class="changelog-version">
            <h3>v1.3.4 — наступний реліз</h3>
            <h4>Завантаження Android та надійність галереї</h4>
            <ul>
                <li><strong>Фонове завантаження</strong> продовжується після згортання застосунку або вимкнення екрана</li>
                <li><strong>Постійні позначки завантажених файлів</strong> зберігаються між запусками</li>
                <li><strong>Надійніші мініатюри та прев'ю</strong> завдяки перевірці JPEG, повторним спробам і резервному завантаженню</li>
            </ul>
        </div>
'''
ru_log = '''        <div class="changelog-version">
            <h3>v1.3.4 — следующий релиз</h3>
            <h4>Загрузки Android и надёжность галереи</h4>
            <ul>
                <li><strong>Фоновое скачивание</strong> продолжается после сворачивания приложения или выключения экрана</li>
                <li><strong>Постоянные метки скачанных файлов</strong> сохраняются между запусками</li>
                <li><strong>Более надёжные миниатюры и превью</strong> благодаря проверке JPEG, повторным попыткам и резервной загрузке</li>
            </ul>
        </div>
'''
html = insert_before(html, '        <div class="changelog-version">\n            <h3>v1.3.2 — August 15, 2026</h3>', en_log, 'EN changelog')
html = insert_before(html, '        <div class="changelog-version">\n            <h3>v1.3.2 — 15 серпня 2026</h3>', uk_log, 'UK changelog')
html = insert_before(html, '        <div class="changelog-version">\n            <h3>v1.3.2 — 15 августа 2026</h3>', ru_log, 'RU changelog')

# Performance / privacy cleanup: merge the two style blocks and remove external Google Fonts.
first_style = html.index('<style>')
first_close = html.index('</style>', first_style)
typography = html.index('<!-- Typography -->', first_close)
second_style = html.index('<style>', typography)
second_close = html.index('</style>', second_style)
second_css = html[second_style + len('<style>'):second_close]
second_css = second_css.replace("font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;", "font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;")
second_css = second_css.replace("font-family: 'JetBrains Mono', 'Consolas', monospace;", "font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;")
second_css += '''\n\n  :root { color-scheme: dark; }\n  @media (max-width: 520px) {\n    .lang-bar { padding-left: 48px; padding-right: 48px; gap: 4px; }\n    .lang-bar button { padding: 6px 9px; font-size: 0.78rem; }\n    .lang-bar .brand { left: 14px; }\n    .github-link { right: 14px; }\n    .hero { padding: 72px 16px 56px; }\n    .hero-badges .badge { width: 100%; max-width: 320px; }\n  }\n  @media (prefers-reduced-motion: reduce) {\n    *, *::before, *::after { animation-duration: .001ms !important; transition-duration: .001ms !important; }\n  }\n'''
html = html[:first_close] + second_css + '\n</style>' + html[second_close + len('</style>'):]

# Language switch accessibility.
html = html.replace('<nav class="lang-bar">', '<nav class="lang-bar" aria-label="Language and project navigation">')
html = html.replace('<button class="active" onclick="switchLang(\'en\')">English</button>', '<button type="button" class="active" aria-pressed="true" onclick="switchLang(\'en\')">English</button>')
html = html.replace('<button onclick="switchLang(\'uk\')">Українська</button>', '<button type="button" aria-pressed="false" onclick="switchLang(\'uk\')">Українська</button>')
html = html.replace('<button onclick="switchLang(\'ru\')">Русский</button>', '<button type="button" aria-pressed="false" onclick="switchLang(\'ru\')">Русский</button>')

# Sanity checks.
for required in ['Background Download', 'Already Downloaded', 'Фонове завантаження', 'Вже завантажено', 'Фоновое скачивание', 'Уже скачано', 'v1.3.4 — next release']:
    if required not in html:
        raise SystemExit(f'missing: {required}')
if html.count('<style>') != 1 or html.count('</style>') != 1:
    raise SystemExit('CSS blocks were not merged')
if 'fonts.googleapis.com' in html or 'fonts.gstatic.com' in html:
    raise SystemExit('Google Fonts references remain')
if 'v1.3.2 APK<br>' in html:
    raise SystemExit('stale download-card version remains')

HTML.write_text(html, encoding='utf-8')
print('Documentation updated')
