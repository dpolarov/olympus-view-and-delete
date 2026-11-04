# Olympus View landing page — unslop design audit

This redesign uses [unslop by Damir Sokolovsky](https://github.com/heydamir/unslop), CC BY 4.0. The project-local skill is in [`.agents/skills/unslop/`](../.agents/skills/unslop/SKILL.md), including its license, references, scripts and reference images.

## Before: audit

- The old hero combined a radial blue wash, a grid overlay and blue gradient text.
- The primary screen had four equally weighted actions and no actual product view.
- Feature cards and camera tags used glows, gradient fills and lift animations.
- Feature and download icons were assorted colorful emoji rather than a consistent visual language.
- The layout relied on 960px-centered content, uniform cards and a giant centered headline.
- Several visual effects competed with the product screenshots lower on the page.
- Feedback forms, FAQ, three locale sections, software metadata and release notes were meaningful and needed to stay.

## Direction

- **Product:** a Wi-Fi file manager for Olympus and OM System cameras, used to view, download and delete photos, RAW and video files.
- **Character:** precise, tactile, understated.
- **World:** matte camera housings, optical glass, viewfinder markings, and real photographs.
- **Moments:** the existing Olympus View/OM-1 gallery screenshot in the hero, and the original gallery/connection screenshots below.
- **Signature:** a small flat coral-red shutter/status mark; no glowing indicators.

## Design passes

1. **Spacing:** use a consistent 4px rhythm, generous section separation, smaller gaps inside related groups and aligned card padding.
2. **Color:** matte charcoal camera-shell surfaces, neutral hairlines and off-white text. The existing app's coral/pink direction remains as a restrained accent.
3. **Icons:** replace feature emojis with aligned, subdued numeric markers (01–08), and remove duplicated platform emojis from download cards.
4. **Copy:** explain the actual camera actions in EN/RU/UK. The hero offers one main Android download action and one secondary link to all platforms. Keep the original sections and content.
5. **Type:** restrained system typography with lighter headline weights, a clear display scale and normal-case labels.
6. **Layout:** split hero with a real product screenshot; asymmetric first two feature cards; responsive two- and one-column layouts below 820px and 640px.
7. **Details:** modest radii, quiet borders, stable controls, clear focus states and no scale-on-hover animations.
8. **Visuals:** reuse `docs/img/gallery.jpg` and existing screenshots; no generated or invented camera imagery.
9. **Motion:** brief color/border state transitions; respect `prefers-reduced-motion`.

## Compatibility and checks

- `docs/index.html` contains the EN/RU/UK sections and retains the language switcher, release/download links, screenshots, FAQ, feedback forms, JSON-LD and GitHub Pages changelog anchors.
- `docs/unslop.css` is loaded **after** the legacy inline CSS and is the final authority for visual styling. A future cleanup can consolidate earlier rules once the new visuals have been verified on real devices.
- `scripts/check_website_design.py` tests locale/hero parity, static assets, download links, release anchors, accessible focus and reduced motion. The Pages workflow runs this check on each relevant CI build.
- Cosmetic website changes do not change the Flutter app version or create a release tag.
- Visual/manual browser QA should include 375px, 768px and 1440px widths; test all languages, downloadable links, anchor links and form submission. Automated static checks do not replace device testing.

## Credit

Unslop was created by **Damir Sokolovsky** ([@heydamir](https://x.com/heydamir)). Original skill and assets are redistributed under **CC BY 4.0** with attribution and the copied license. This Olympus View redesign is based on the project's own product and screenshots.
