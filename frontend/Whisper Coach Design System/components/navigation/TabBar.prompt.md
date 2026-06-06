Bottom tab bar for the Whisper Coach app shell.

```jsx
const [tab, setTab] = React.useState("create");
<TabBar value={tab} onChange={setTab} items={[
  { key: "create", label: "Create", icon: "plus-circle" },
  { key: "lineup", label: "Lineup", icon: "layout-grid" },
  { key: "live",   label: "Live",   icon: "message-circle" },
]} />
```

The grid auto-sizes to the number of `items`. The active tab uses brand green.
