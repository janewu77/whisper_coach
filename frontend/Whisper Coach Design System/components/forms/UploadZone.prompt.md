Dashed photo-upload target that anchors the "snap your roster, AI extracts the players" flow.

```jsx
const [status, setStatus] = React.useState("idle");
<UploadZone status={status} count={14}
  onClick={() => { setStatus("processing"); setTimeout(() => setStatus("done"), 1500); }} />
```

States: `idle` (camera prompt), `processing` (spinner), `done` (green confirm + detected count). Override copy with `title` / `hint` if needed.
