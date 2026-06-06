Selectable pill — the formation picker, filters, segmented options.

```jsx
{["4-3-3","4-2-3-1","3-5-2"].map(f => (
  <Chip key={f} selected={formation === f} onClick={() => setFormation(f)}>{f}</Chip>
))}
```

Controlled via `selected`. Renders as a button (`aria-pressed`). Lay several out in a flex row with `gap`.
