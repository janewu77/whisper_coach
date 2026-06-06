# Whisper Coach — Design System

**Whisper Coach** is an AI tactical assistant for grassroots & amateur football (soccer) coaches. The mobile app (Flutter) walks a coach through one match at a time:

1. **Create match** — snap a photo of the team roster; AI extracts the player names. Set the opponent, match type and notes.
2. **Lineup** — AI proposes a formation and starting XI on a pitch (4-3-3 / 4-2-3-1 / 3-5-2), with plain-language reasoning. The coach can switch formations and tweak positions.
3. **Live match** — during the game the coach logs events by voice or text and gets real-time tactical suggestions and substitution advice, in a chat-style log.

The voice is a calm, knowledgeable assistant coach "whispering" guidance in the moment — hence the name.

### Brand theme
Green + white **football** palette: an emerald brand green (`#1D9E75`) for interactive elements, grass **pitch** greens for the field, warm-neutral "stone" greys, and soft amber/red tactical status colors. Quiet, flat, iOS-native feel; system typography for UI with **Hanken Grotesk** as the display face for the wordmark and big numbers.

### Sources
- **`uploads/ui_prototype.html`** — the source HTML prototype provided by the user. Source of truth for layout, palette, copy and component behaviour. The token values, the three screens, and the green theme are all derived from it.
- Target platform: **Flutter** (mobile). This system is currently a **design-phase reference** — the React components are visual specs, not code to port.
- No logo files, Figma, or codebase were supplied.

---

## CONTENT FUNDAMENTALS

**Voice.** A composed, expert assistant-coach. It states the situation, then a concrete recommendation. Confident but never loud — it advises, it doesn't shout.

**Person & address.** Speaks *to* the coach in the imperative ("Drop Lima 10m deeper", "Bring on Kowalski"). The assistant refers to itself only as **Whisper Coach** in message headers, rarely "I". The coach is the decision-maker; the app proposes.

**Tone by surface.**
- *Setup copy* is plain and instructional: "Upload team roster photo", "AI will extract player names automatically".
- *AI tactical copy* leads with a bold label then the action: **"Suggestion:"** Drop Lima… / **"Substitution:"** Replace Diallo (CM) with Kowalski — fresh legs in center.
- *Reasoning* is short, causal, football-literate: "Opponent runs a strong central midfield. 4-3-3 gives you a numerical advantage in center."

**Casing.** Sentence case everywhere for titles and buttons ("New match", "Generate lineup", "Start match"). UPPERCASE only for small tracked section labels ("DETECTED PLAYERS"). Player tags use real-name casing ("M. Chen", "K. Müller").

**Numbers & football terms.** Match minute with a prime ("23'", "38'"). Formations hyphenated ("4-3-3"). Position codes in caps (GK, CB, LB, CM, ST, LW). Score with an en-dash ("2–1").

**Length.** Terse. One idea per message. AI suggestions are 1–2 sentences. Buttons are 1–3 words, often with a leading icon.

**Emoji.** Avoid in product chrome and AI copy. The source prototype used emoji on a couple of quick-action buttons (⚽🚑📋) — in this system those are replaced by **Tabler icons** (`ball-football`, `ambulance`, `clipboard-text`) for consistency. If you want emoji back on quick actions, that's a deliberate choice to flag.

---

## VISUAL FOUNDATIONS

**Color.** Emerald **brand green `#1D9E75`** is the single interactive accent — primary buttons, active tab, selected chips, focus rings, the mic. Dark green `#0F6E56` (`--text-brand`) labels AI/reasoning content. **Pitch greens** (`#2D7A3E` turf, lighter/darker stripes) are reserved for the field. Neutrals are a **warm stone** ramp (page `#F5F5F4`, cards white, text `#1A1A1A`/`#666`/`#999`). Status is soft-pill only: green (available/on-plan), amber (caution/doubtful), red (risk/live), plus an inverse near-black for the "AI" badge. No blues, no purple, no gradients on chrome.

**Type.** System sans (`-apple-system`) carries the entire UI — sizes 10–17px, weights **400 and 500** doing almost all the work (500 = "emphasis"; 600 only occasionally; 700 only for display). **Hanken Grotesk** is the display face for the wordmark, big numbers and scores, with `tabular-nums` for stats and minutes. Uppercase section labels use 11px / 500 / `0.06em` tracking. Line-height 1.5 for UI, 1.55 for chat/reasoning.

**Spacing & shape.** 4px base grid. Screen padding 16px, 12px between cards. Radii: inputs/buttons **8px**, cards **12px**, app shell/sheets **16px**, tags/chips **pill**. Hit targets ≥ 38px (mic/send are 38; primary CTA ~46).

**Surfaces, borders & elevation.** The UI is **flat**: cards are white with a **0.5px hairline border** (`rgba(0,0,0,.12)`), not shadows. Inputs/chips use a slightly stronger hairline (`rgba(0,0,0,.2)`). Shadow is reserved for things that truly float — the phone shell (`0 8px 40px rgba(0,0,0,.12)`) and popovers/sheets. No inner shadows. No heavy drop shadows on cards.

**Backgrounds.** Solid only — white cards on a `#F5F5F4` page. The one textured surface is the **pitch**: solid turf green with faint mowing stripes and white line markings. No imagery, no patterns elsewhere, no protection gradients.

**The pitch motif.** The signature element. Vertical orientation, GK at the bottom (~y 88%), forwards at the top (~y 22%). Players are 38px white discs with a 2.5px green ring and small initials + position; the selected/active player inverts to solid green. A dark "AI generated" pill sits bottom-right.

**Cards.** White, 12px radius, 0.5px hairline, 14×16px padding, no shadow. The **tinted** variant (soft green fill + green hairline) marks AI/reasoning content. A **sunken** variant uses the stone fill.

**Motion.** Quiet and quick. State changes transition over **150ms** with a standard ease; presses scale to ~0.96; the only looping animation is the upload spinner (disabled under `prefers-reduced-motion`). No bounces on content, no decorative motion.

**Interaction states.**
- *Hover* (where pointers exist): primary lightens to green-400; neutral fills go one stone step darker; chips/tags tint.
- *Press*: subtle `scale(.96–.97)`; primary darkens to green-600.
- *Selected*: brand-subtle green fill, green-300 border, dark-green text (chips, pitch dots invert to solid green).
- *Focus*: 3px brand-green ring (`--ring-brand`), no default outline.
- *Disabled*: ~45% opacity, not-allowed cursor.

**Transparency / blur.** Essentially none in the product chrome (this is a flat, opaque UI). Reserve any blur for future iOS-style overlays only.

---

## ICONOGRAPHY

**Tabler Icons**, used as a **webfont via CDN** (`@tabler/icons-webfont`). Line style, consistent ~1.75px stroke, on a 24px grid. UI icons render 14–24px; tab-bar icons 22px; they inherit `currentColor` so they tint with text/brand color. Components accept an icon name **without** the `ti-` prefix.

The brand mark uses `ball-football`. AI/coach contexts use `cpu`; reasoning uses `bulb`; generation uses `wand`. See **`assets/README.md`** for the full glyph list and the Flutter equivalent (`tabler_icons` package or exported SVGs).

No emoji in chrome (see Content Fundamentals). No bespoke/hand-drawn SVG icons — stay within the Tabler set so weight and metrics stay consistent.

---

## ⚠️ Substitutions to confirm
- **Display font:** *Hanken Grotesk* (Google Fonts CDN) is used as a stand-in brand display face. If you have a licensed/preferred display face, send the files and I'll self-host it (`assets/fonts/` + `@font-face`). The UI font is the native system stack, so this only affects the wordmark, headlines and big numbers.
- **Quick-action emoji → Tabler icons** (see Content Fundamentals). Tell me if you'd rather keep emoji.
- **No real logo/app-icon** — the wordmark is a typographic placeholder lockup. Please supply the real mark.

---

## INDEX / MANIFEST

**Root**
- `styles.css` — global entry point; consumers link this. `@import`s the token files only.
- `readme.md` — this guide.
- `SKILL.md` — Agent-Skills front-matter so this system can be used as a downloadable skill.

**Tokens** (`tokens/`, all reached from `styles.css`)
- `colors.css` · `typography.css` · `spacing.css` · `elevation.css` · `motion.css` · `fonts.css`

**Foundations** (`guidelines/foundations/`, Design System tab specimen cards)
- Colors: brand green · pitch green · neutrals · status
- Type: display & scores · titles & UI text · labels & numerals
- Spacing: scale · radii · elevation
- Brand: wordmark & app mark · iconography

**Components** (`components/`, exported on `window.WhisperCoachDesignSystem_6c0cf7`)
- `core/` — Button, IconButton, Card, Badge, Tag, Chip
- `forms/` — Input, Select, UploadZone
- `navigation/` — TabBar
- `chat/` — ChatBubble
- `pitch/` — Pitch, PlayerDot *(signature)*

Each component directory has `<Name>.jsx`, `<Name>.d.ts`, `<Name>.prompt.md`, and one `@dsCard` HTML demo.

**UI kit** (`ui_kits/app/`)
- `index.html` — static screen-reference sheet (New Match · Lineup · Live). See its `README.md`.

**Assets** (`assets/`)
- `README.md` — iconography (Tabler) + brand-imagery notes. No binaries supplied yet.
