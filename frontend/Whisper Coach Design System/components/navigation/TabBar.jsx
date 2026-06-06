import React from "react";

const TABBAR_STYLE_ID = "wc-tabbar-styles";
function ensureTabBarStyles() {
  if (typeof document === "undefined" || document.getElementById(TABBAR_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = TABBAR_STYLE_ID;
  el.textContent = `
.wc-tabbar{display:grid;background:var(--surface-card);
  border-top:var(--border-width-hairline) solid var(--border-subtle);
  padding:8px 0 12px;font-family:var(--font-sans);}
.wc-tab{display:flex;flex-direction:column;align-items:center;gap:3px;
  background:none;border:none;cursor:pointer;padding:4px;
  font-size:var(--text-2xs);color:var(--text-tertiary);
  transition:color var(--duration-base) var(--ease-standard);}
.wc-tab i{font-size:22px;}
.wc-tab:hover{color:var(--text-secondary);}
.wc-tab.is-active{color:var(--brand);}`;
  document.head.appendChild(el);
}

/**
 * Bottom navigation bar. Pass `items` ([{key,label,icon}]) and the
 * active `value`; the grid auto-sizes to the number of tabs.
 */
export function TabBar({ items = [], value, onChange, style, className = "", ...rest }) {
  ensureTabBarStyles();
  return (
    <nav
      className={`wc-tabbar ${className}`.trim()}
      style={{ gridTemplateColumns: `repeat(${items.length}, 1fr)`, ...style }}
      {...rest}
    >
      {items.map((it) => (
        <button
          key={it.key}
          type="button"
          className={`wc-tab${value === it.key ? " is-active" : ""}`}
          aria-current={value === it.key ? "page" : undefined}
          onClick={() => onChange && onChange(it.key)}
        >
          <i className={`ti ti-${it.icon}`} aria-hidden="true" />
          {it.label}
        </button>
      ))}
    </nav>
  );
}
