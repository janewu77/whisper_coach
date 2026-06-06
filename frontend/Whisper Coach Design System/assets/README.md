# Assets

## Icons — Tabler Icons (webfont, via CDN)
The product uses **[Tabler Icons](https://tabler.io/icons)** as a webfont, loaded from the jsDelivr CDN:

```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@latest/tabler-icons.min.css" />
```

Usage: `<i class="ti ti-microphone"></i>`. In components, pass the icon name **without** the `ti-` prefix (e.g. `icon="microphone"`). Line style, ~1.75px stroke, sized 14–24px in UI, 22px in the tab bar.

Core glyphs in play: `ball-football` (brand mark), `plus-circle`, `layout-grid`, `message-circle`, `cpu` (AI), `bulb` (reasoning), `wand` (generate), `player-play`, `microphone`, `send`, `camera`, `whistle`, `arrows-shuffle`, `clipboard-text`, `ambulance`, `chevron-down`.

> **Flutter:** the closest equivalent is the [`tabler_icons`](https://pub.dev/packages?q=tabler) package family, or export the SVGs you need from tabler.io and bundle them as `flutter_svg` assets. Keep the line weight and 24px grid.

## Brand imagery
No logo / illustration / photography files were supplied. The wordmark is a **typographic lockup** ("Whisper **Coach**" in Hanken Grotesk) paired with the `ball-football` glyph on a brand-green rounded-square mark — see `guidelines/foundations/brand-logo.html`.

**Needed from you:** a real app icon / logo, and any photography style direction. Drop files here and I'll wire them in.
