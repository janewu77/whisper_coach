import React from "react";

const CHIP_STYLE_ID = "wc-chip-styles";
function ensureChipStyles() {
  if (typeof document === "undefined" || document.getElementById(CHIP_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = CHIP_STYLE_ID;
  el.textContent = `
.wc-chip{display:inline-flex;align-items:center;gap:6px;font-family:var(--font-sans);
  font-size:var(--text-base);font-weight:var(--weight-medium);line-height:1;
  padding:6px 12px;border-radius:var(--radius-pill);cursor:pointer;
  background:var(--surface-sunken);color:var(--text-secondary);
  border:var(--border-width-hairline) solid var(--border-subtle);
  transition:var(--transition-colors),transform var(--duration-fast) var(--ease-standard);}
.wc-chip:not(.is-selected):hover{background:var(--stone-200);color:var(--text-primary);}
.wc-chip:active{transform:scale(.96);}
.wc-chip:focus-visible{outline:none;box-shadow:0 0 0 3px var(--ring-brand);}
.wc-chip.is-selected{background:var(--brand-subtle);color:var(--text-brand);border-color:var(--brand-border);}`;
  document.head.appendChild(el);
}

/**
 * Selectable pill — formation picker (4-3-3 / 4-2-3-1), filters, segmented
 * options. Toggle `selected` from the parent.
 */
export function Chip({ children, selected = false, icon, onClick, style, className = "", ...rest }) {
  ensureChipStyles();
  return (
    <button
      type="button"
      className={`wc-chip${selected ? " is-selected" : ""} ${className}`.trim()}
      aria-pressed={selected}
      onClick={onClick}
      style={style}
      {...rest}
    >
      {icon && <i className={`ti ti-${icon}`} style={{ fontSize: 14 }} aria-hidden="true" />}
      {children}
    </button>
  );
}
