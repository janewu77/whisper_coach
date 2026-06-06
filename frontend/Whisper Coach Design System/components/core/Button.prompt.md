Primary action button — the green CTA that drives the main flow ("Generate lineup", "Start match"); use secondary/ghost for lower-emphasis actions.

```jsx
<Button variant="primary" icon="wand" fullWidth onClick={generate}>
  Generate lineup
</Button>
```

Variants: `primary` (green, default), `secondary` (neutral fill + hairline), `subtle` (tinted green), `ghost` (text-only green), `danger` (red). Sizes: `sm` / `md` / `lg`. Pass `icon` / `iconRight` as a Tabler glyph name (without the `ti-` prefix). Use `fullWidth` for the bottom-of-screen CTA.
