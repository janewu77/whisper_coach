import React from "react";

const DOT_STYLE_ID = "wc-playerdot-styles";
function ensurePlayerDotStyles() {
  if (typeof document === "undefined" || document.getElementById(DOT_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = DOT_STYLE_ID;
  el.textContent = `
.wc-dot{position:absolute;transform:translate(-50%,-50%);display:flex;flex-direction:column;
  align-items:center;justify-content:center;text-align:center;cursor:pointer;
  border-radius:var(--radius-pill);background:#fff;color:var(--text-brand);
  border:2.5px solid var(--brand);font-family:var(--font-sans);font-weight:var(--weight-medium);
  line-height:1.15;transition:var(--transition-colors),transform var(--duration-base) var(--ease-standard);}
.wc-dot:hover,.wc-dot.is-selected{background:var(--brand);color:#fff;border-color:#fff;z-index:10;}
.wc-dot.is-selected{transform:translate(-50%,-50%) scale(1.08);}
.wc-dot__name{font-size:10px;}
.wc-dot__pos{font-size:8px;opacity:.85;letter-spacing:.02em;}`;
  document.head.appendChild(el);
}

/**
 * A single player token on the pitch. Positioned by `x`/`y` percentages
 * (relative to the pitch). Shows initials + a position label.
 */
export function PlayerDot({ name, pos, x, y, size = 38, selected = false, onClick, style, className = "", ...rest }) {
  ensurePlayerDotStyles();
  const positioned = x != null && y != null;
  return (
    <button
      type="button"
      className={`wc-dot${selected ? " is-selected" : ""} ${className}`.trim()}
      onClick={onClick}
      style={{
        width: size,
        height: size,
        ...(positioned ? { left: `${x}%`, top: `${y}%`, position: "absolute" } : { position: "relative", transform: "none" }),
        ...style,
      }}
      {...rest}
    >
      {name && <span className="wc-dot__name">{name}</span>}
      {pos && <span className="wc-dot__pos">{pos}</span>}
    </button>
  );
}
