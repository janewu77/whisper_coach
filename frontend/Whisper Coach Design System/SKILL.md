---
name: whisper-coach-design
description: Use this skill to generate well-branded interfaces and assets for Whisper Coach (an AI tactical assistant for grassroots football coaches), either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

## Quick map
- `readme.md` — the design guide (brand, content fundamentals, visual foundations, iconography, manifest). Read this first.
- `styles.css` — global CSS entry point; `@import`s all tokens. Link this to inherit colors, type, spacing, radii, shadows, motion.
- `tokens/` — the raw CSS custom properties.
- `components/` — React UI primitives (Button, IconButton, Card, Badge, Tag, Chip, Input, Select, UploadZone, TabBar, ChatBubble, Pitch, PlayerDot). Each has a `.prompt.md` with usage.
- `guidelines/foundations/` — specimen cards for colors, type, spacing, brand.
- `ui_kits/app/` — static screen-reference sheet for the mobile app.

## Notes
- Brand color: emerald green `#1D9E75`; pitch turf `#2D7A3E`; warm-stone neutrals; flat, hairline-bordered, iOS-native feel.
- Icons: Tabler Icons webfont (`ti ti-<name>`).
- Target platform is **Flutter** — when doing native work, map the tokens to a Flutter theme rather than porting the React components verbatim.
- Display font Hanken Grotesk is a CDN stand-in; confirm the real brand face with the user before finalizing.
