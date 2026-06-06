A single message in the live-match coaching conversation.

```jsx
<ChatBubble role="user">Left side is being exposed. Torres is out of position.</ChatBubble>

<ChatBubble role="assistant" time="23'" lead="Suggestion:">
  Drop Lima 10m deeper and rotate Torres to track the run.
</ChatBubble>
```

`assistant` renders the neutral AI card with a "Whisper Coach" header and cpu glyph; `user` renders the green right-aligned bubble. Use `lead` to bold a prefix ("Suggestion:", "Substitution:"). Lay bubbles in a vertical flex column with `gap`.
