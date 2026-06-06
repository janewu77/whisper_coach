The signature Whisper Coach element — a tactical pitch with positioned players.

```jsx
const [sel, setSel] = React.useState(null);
<Pitch aiBadge selectedId={sel} onSelectPlayer={setSel} players={[
  { id: "gk", name: "H.Y", pos: "GK", x: 50, y: 88 },
  { id: "lb", name: "G.L", pos: "LB", x: 15, y: 72 },
  { id: "st", name: "O.S", pos: "ST", x: 50, y: 22 },
  // …
]} />
```

Vertical orientation, GK at the bottom (~y 88), forwards at the top (~y 22). Pass `aiBadge` to show the "AI generated" marker. Tapping a dot calls `onSelectPlayer`. Pair with `<Chip>` formation pickers and a tinted `<Card>` for AI reasoning.
