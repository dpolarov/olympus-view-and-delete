#!/usr/bin/env python3
"""Non-invasive checks for the Olympus View GitHub Pages landing page.

No external dependencies. Run locally with:
    python3 scripts/check_website_design.py
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
html = (ROOT / "docs/index.html").read_text(encoding="utf-8")
css_path = ROOT / "docs/unslop.css"
css = css_path.read_text(encoding="utf-8")

def check(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"Website design check failed: {message}")

check(html.count('<link rel="stylesheet" href="unslop.css">') == 1,
      "site must load the unslop stylesheet exactly once")
check(html.index("</style>") < html.index('href="unslop.css"'),
      "new stylesheet must follow legacy inline rules")
check((ROOT / "docs/img/gallery.jpg").is_file(), "real gallery screenshot is missing")
check(len(re.findall(r'<section class="hero">', html)) == 3,
      "every locale needs one hero")
check(len(re.findall(r'class="hero-scene"', html)) == 3,
      "every locale needs the same real product visual")
check(len(re.findall(r'class="feature-icon" aria-hidden="true">\d{2}</div>', html)) == 24,
      "feature numbering must be consistent across all locales")
check('class="download-icon"' not in html, "decorative download emojis must be removed")
check("linear-gradient" not in css and "radial-gradient" not in css,
      "new visual stylesheet must not reintroduce colored gradients")
check("@media (max-width: 640px)" in css and "@media (max-width: 820px)" in css,
      "responsive breakpoints are missing")
check("@media (prefers-reduced-motion: reduce)" in css,
      "reduced-motion preference must be respected")
check("focus-visible" in css, "keyboard focus states are missing")
check(html.count('class="feedback-form"') == 3,
      "keep feedback forms on all localized pages")
for lang in ("en", "ru", "uk"):
    check(f'id="lang-{lang}"' in html, f"missing {lang} section")
    check(f'id="changelog-{lang}"' in html, f"missing {lang} changelog")
    check(f'id="dl-{lang}"' in html, f"missing {lang} download anchor")
    section = re.search(rf'<div id="lang-{lang}" class="lang-section(?: active)?">(.*?)(?=<div id="lang-(?:en|ru|uk)"|<!-- End|$)', html, re.S)
    check(section is not None, f"cannot parse {lang} content")
    loc = section.group(1)
    check('class="hero-layout"' in loc, f"{lang} uses the old centered hero")
    check(f'href="#dl-{lang}"' in loc, f"{lang} other-platforms button is broken")
    check('src="img/gallery.jpg"' in loc, f"{lang} is missing product screenshot")
    check('releases/latest/download/OlympusView-Android.apk' in loc,
          f"{lang} Android download link is missing")
check('<!-- RELEASE_VERSION:' in (ROOT / "docs/current-release.html").read_text(encoding="utf-8"),
      "must retain current-release injection contract")
print("Website design checks passed: EN/RU/UK, assets, downloads, release anchors, accessibility and responsive CSS")
