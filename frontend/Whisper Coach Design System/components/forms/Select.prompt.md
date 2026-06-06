Styled native select with a chevron — match type, season, etc.

```jsx
<Select label="Match type" options={[
  "Balanced — similar level",
  "Strong opponent — defend first",
  "Weaker opponent — press high",
]} />
```

Pass `options` as strings or `{value,label}` objects, or supply `<option>` children. Omit `label` for a bare control.
