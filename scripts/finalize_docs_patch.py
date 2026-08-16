from pathlib import Path

readme_path = Path('README.md')
html_path = Path('docs/index.html')
readme = readme_path.read_text(encoding='utf-8')
html = html_path.read_text(encoding='utf-8')

replacements = [
    ('8. **Download button** — download selected files\n9. **Delete button** — delete selected files from the camera',
     '8. **Download button** — download selected files; on Android choose **On screen** or **Background**\n9. Successfully downloaded files remain marked in green after restarting the app\n10. **Delete button** — delete selected files from the camera'),
    ('8. **Кнопка завантаження** — завантажити вибрані файли\n9. **Кнопка видалення** — видалити вибрані файли з камери',
     '8. **Кнопка завантаження** — завантажити вибрані файли; на Android виберіть **На екрані** або **У фоні**\n9. Успішно завантажені файли залишаються позначеними зеленим після перезапуску\n10. **Кнопка видалення** — видалити вибрані файли з камери'),
    ('8. **Кнопка скачивания** — скачать выбранные файлы\n9. **Кнопка удаления** — удалить выбранные файлы с камеры',
     '8. **Кнопка скачивания** — скачать выбранные файлы; на Android выберите **На экране** или **В фоне**\n9. Успешно скачанные файлы остаются отмеченными зелёным после перезапуска\n10. **Кнопка удаления** — удалить выбранные файлы с камеры'),
]
for old, new in replacements:
    if old not in readme:
        raise SystemExit(f'README marker missing: {old[:40]}')
    readme = readme.replace(old, new, 1)

# Avoid a time-sensitive competitive claim; open-source/proprietary distinction is enough.
html = html.replace('OI.Share is closed and no longer updated', 'OI.Share is proprietary')
html = html.replace('OI.Share закритий і більше не оновлюється', 'OI.Share має закритий вихідний код')
html = html.replace('OI.Share закрытый и больше не обновляется', 'у OI.Share закрытый исходный код')

old_js = """    document.querySelectorAll('.lang-bar button').forEach(b => b.classList.remove('active'));
    document.getElementById('lang-' + lang).classList.add('active');
    document.querySelector('.lang-bar button[onclick*=\"\\'' + lang + '\\'\"]').classList.add('active');"""
new_js = """    document.querySelectorAll('.lang-bar button').forEach(b => {
        b.classList.remove('active');
        b.setAttribute('aria-pressed', 'false');
    });
    document.getElementById('lang-' + lang).classList.add('active');
    const activeButton = document.querySelector('.lang-bar button[onclick*=\"\\'' + lang + '\\'\"]');
    activeButton.classList.add('active');
    activeButton.setAttribute('aria-pressed', 'true');"""
if old_js not in html:
    raise SystemExit('switchLang JS marker missing')
html = html.replace(old_js, new_js, 1)

readme_path.write_text(readme, encoding='utf-8')
html_path.write_text(html, encoding='utf-8')
print('Final documentation polish applied')
