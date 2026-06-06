Icon-only button for compact controls — the mic and send buttons in the live composer, toolbar actions.

```jsx
<IconButton icon="microphone" variant="solid" label="Voice input" />
<IconButton icon="send" variant="neutral" label="Send" onClick={send} />
```

Variants: `solid` (green), `neutral` (fill + hairline), `ghost`. Sizes `sm`/`md`/`lg` map to 32/38/44px. Pass `recording` to flip the mic to its red stop state. Always supply `label` for accessibility.
