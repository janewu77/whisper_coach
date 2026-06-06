# Whisper Coach — App screen reference

A **static layout & style reference** for the Whisper Coach mobile app (Flutter), built for the design phase. It is intentionally *not* a click-through prototype — it shows the three core screens side-by-side so the team can read spacing, type, color and component usage at a glance.

- `index.html` — the reference sheet (open it directly).

### Screens
1. **Create match** — roster photo upload (AI extraction), detected-player tags, opponent + match-type form, primary "Generate lineup" CTA.
2. **Lineup** — formation chips, the tactical `Pitch` with positioned players + "AI generated" badge, tinted AI-reasoning card, "Start match" CTA.
3. **Live match** — coaching conversation (`ChatBubble`), voice/text composer, quick-action chips.

Everything is composed from the design-system components (`window.WhisperCoachDesignSystem_6c0cf7`) over the shared tokens in `styles.css`. The phone shell (status bar, header, tab bar placement) mirrors the source prototype.

> Flutter handoff: treat the React components here as *visual specs*, not code to port. Map tokens → a Flutter `ThemeData` / design-token file; the component cards in the Design System tab document each element's states.
