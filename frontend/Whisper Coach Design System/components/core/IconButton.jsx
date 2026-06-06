import React from "react";

const IB_STYLE_ID = "wc-iconbutton-styles";
function ensureIconButtonStyles() {
  if (typeof document === "undefined" || document.getElementById(IB_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = IB_STYLE_ID;
  el.textContent = `
.wc-iconbtn{display:inline-flex;align-items:center;justify-content:center;
  border:var(--border-width-hairline) solid transparent;cursor:pointer;
  border-radius:var(--radius-md);flex-shrink:0;
  transition:var(--transition-colors),transform var(--duration-fast) var(--ease-standard),box-shadow var(--duration-base) var(--ease-standard);}
.wc-iconbtn:focus-visible{outline:none;box-shadow:0 0 0 3px var(--ring-brand);}
.wc-iconbtn:disabled{opacity:.4;cursor:not-allowed;}
.wc-iconbtn:not(:disabled):active{transform:scale(.94);}
.wc-iconbtn--solid{background:var(--brand);color:var(--text-on-brand);}
.wc-iconbtn--solid:not(:disabled):hover{background:var(--brand-hover);}
.wc-iconbtn--neutral{background:var(--surface-sunken);color:var(--text-secondary);border-color:var(--border-default);}
.wc-iconbtn--neutral:not(:disabled):hover{background:var(--stone-200);color:var(--text-primary);}
.wc-iconbtn--ghost{background:transparent;color:var(--text-secondary);}
.wc-iconbtn--ghost:not(:disabled):hover{background:var(--surface-sunken);color:var(--text-primary);}
.wc-iconbtn--recording{background:var(--red-700);color:#fff;}
.wc-iconbtn--round{border-radius:var(--radius-pill);}`;
  document.head.appendChild(el);
}

const IB_SIZES = { sm: 32, md: 38, lg: 44 };

/**
 * A square (or round) tappable icon — the mic / send controls in the
 * live-match composer, toolbar actions, etc.
 */
export function IconButton({
  icon,
  variant = "neutral",
  size = "md",
  round = false,
  recording = false,
  disabled = false,
  onClick,
  label,
  style,
  className = "",
  ...rest
}) {
  ensureIconButtonStyles();
  const dim = IB_SIZES[size] || IB_SIZES.md;
  const v = recording ? "recording" : variant;
  const cls = `wc-iconbtn wc-iconbtn--${v}${round ? " wc-iconbtn--round" : ""} ${className}`.trim();
  return (
    <button
      type="button"
      className={cls}
      disabled={disabled}
      onClick={onClick}
      aria-label={label}
      style={{ width: dim, height: dim, ...style }}
      {...rest}
    >
      <i className={`ti ti-${recording ? "player-stop" : icon}`} style={{ fontSize: Math.round(dim * 0.46) }} aria-hidden="true" />
    </button>
  );
}
