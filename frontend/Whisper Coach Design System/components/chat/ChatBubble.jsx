import React from "react";

const CHAT_STYLE_ID = "wc-chat-styles";
function ensureChatStyles() {
  if (typeof document === "undefined" || document.getElementById(CHAT_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = CHAT_STYLE_ID;
  el.textContent = `
.wc-bubble{font-family:var(--font-sans);border-radius:var(--radius-lg);
  font-size:var(--text-base);line-height:var(--leading-relaxed);}
.wc-bubble--assistant{background:var(--surface-sunken);
  border:var(--border-width-hairline) solid var(--border-subtle);
  padding:12px 14px;align-self:flex-start;max-width:88%;color:var(--text-primary);}
.wc-bubble--user{background:var(--brand);color:var(--text-on-brand);
  padding:10px 14px;align-self:flex-end;max-width:80%;margin-left:auto;}
.wc-bubble__from{display:flex;align-items:center;gap:5px;font-size:var(--text-xs);
  font-weight:var(--weight-medium);color:var(--text-brand);margin-bottom:4px;}
.wc-bubble__from .ti{font-size:13px;}
.wc-bubble__lead{font-weight:var(--weight-medium);}`;
  document.head.appendChild(el);
}

/**
 * A single chat message in the live-match log. `role="assistant"` is the
 * AI/coach card (neutral fill, "Whisper Coach" header); `role="user"` is
 * the green right-aligned bubble. Optional `lead` bolds a prefix like
 * "Suggestion:" or "Substitution:".
 */
export function ChatBubble({ role = "assistant", from = "Whisper Coach", time, lead, children, style, className = "", ...rest }) {
  ensureChatStyles();
  if (role === "user") {
    return (
      <div className={`wc-bubble wc-bubble--user ${className}`.trim()} style={style} {...rest}>
        {children}
      </div>
    );
  }
  return (
    <div className={`wc-bubble wc-bubble--assistant ${className}`.trim()} style={style} {...rest}>
      <div className="wc-bubble__from">
        <i className="ti ti-cpu" aria-hidden="true" />
        {from}{time ? ` · ${time}` : ""}
      </div>
      <div>
        {lead && <span className="wc-bubble__lead">{lead} </span>}
        {children}
      </div>
    </div>
  );
}
