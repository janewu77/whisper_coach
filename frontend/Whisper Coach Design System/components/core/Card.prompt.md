Hairline-bordered container for grouped content (form sections, AI reasoning, list groups).

```jsx
<Card>
  <label>Opponent</label>
  <input placeholder="e.g. FC Riverside" />
</Card>

<Card tinted>AI reasoning: 4-3-3 gives a numerical edge in midfield.</Card>
```

Default is white with a hairline border. `tinted` gives the soft-green AI/reasoning look; `sunken` uses the neutral stone fill. Pass `onClick` to make it a tappable row.
