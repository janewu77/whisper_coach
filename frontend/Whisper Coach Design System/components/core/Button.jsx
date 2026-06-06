import React from "react";

const BTN_STYLE_ID = "wc-button-styles";
function ensureButtonStyles() {
  if (typeof document === "undefined" || document.getElementById(BTN_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = BTN_STYLE_ID;
  el.textContent = `
.wc-btn{display:inline-flex;align-items:center;justify-content:center;gap:6px;
  font-family:var(--font-sans);font-weight:var(--weight-medium);line-height:1;
  border-radius:var(--radius-md);border:var(--border-width-hairline) solid transparent;
  cursor:pointer;white-space:nowrap;text-decoration:none;
  transition:var(--transition-colors),transform var(--duration-fast) var(--ease-standard),box-shadow var(--duration-base) var(--ease-standard);}
.wc-btn:focus-visible{outline:none;box-shadow:0 0 0 3px var(--ring-brand);}
.wc-btn:disabled{opacity:.45;cursor:not-allowed;}
.wc-btn:not(:disabled):active{transform:scale(.97);}
.wc-btn--primary{background:var(--brand);color:var(--text-on-brand);}
.wc-btn--primary:not(:disabled):hover{background:var(--brand-hover);}
.wc-btn--primary:not(:disabled):active{background:var(--brand-pressed);}
.wc-btn--secondary{background:var(--surface-sunken);color:var(--text-primary);border-color:var(--border-default);}
.wc-btn--secondary:not(:disabled):hover{background:var(--stone-200);}
.wc-btn--subtle{background:var(--brand-subtle);color:var(--text-brand);}
.wc-btn--subtle:not(:disabled):hover{background:var(--green-100);}
.wc-btn--ghost{background:transparent;color:var(--brand);}
.wc-btn--ghost:not(:disabled):hover{background:var(--brand-subtle);}
.wc-btn--danger{background:var(--red-700);color:#fff;}
.wc-btn--danger:not(:disabled):hover{filter:brightness(1.08);}
.wc-btn--full{width:100%;}`;
  document.head.appendChild(el);
}

const BTN_SIZES = {
  sm: { padding: "7px 12px", fontSize: "var(--text-sm)", icon: 14 },
  md: { padding: "9px 16px", fontSize: "var(--text-md)", icon: 16 },
  lg: { padding: "13px 16px", fontSize: "var(--text-lg)", icon: 17 },
};

/**
 * Primary action button. The green primary is the app's main CTA
 * ("Generate lineup", "Start match"); secondary/ghost are quieter.
 */
export function Button({
  children,
  variant = "primary",
  size = "md",
  fullWidth = false,
  icon,
  iconRight,
  disabled = false,
  onClick,
  type = "button",
  style,
  className = "",
  ...rest
}) {
  ensureButtonStyles();
  const s = BTN_SIZES[size] || BTN_SIZES.md;
  const cls = `wc-btn wc-btn--${variant}${fullWidth ? " wc-btn--full" : ""} ${className}`.trim();
  return (
    <button
      type={type}
      className={cls}
      disabled={disabled}
      onClick={onClick}
      style={{ padding: s.padding, fontSize: s.fontSize, ...style }}
      {...rest}
    >
      {icon && <i className={`ti ti-${icon}`} style={{ fontSize: s.icon }} aria-hidden="true" />}
      {children}
      {iconRight && <i className={`ti ti-${iconRight}`} style={{ fontSize: s.icon }} aria-hidden="true" />}
    </button>
  );
}
