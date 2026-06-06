import React from "react";

const SELECT_STYLE_ID = "wc-select-styles";
function ensureSelectStyles() {
  if (typeof document === "undefined" || document.getElementById(SELECT_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = SELECT_STYLE_ID;
  el.textContent = `
.wc-field{display:block;font-family:var(--font-sans);}
.wc-field__label{display:block;font-size:var(--text-base);color:var(--text-secondary);margin-bottom:6px;}
.wc-select-wrap{position:relative;display:block;font-family:var(--font-sans);}
.wc-select-wrap .ti{position:absolute;right:12px;top:50%;transform:translateY(-50%);
  pointer-events:none;color:var(--text-tertiary);font-size:18px;}
.wc-select{width:100%;box-sizing:border-box;appearance:none;-webkit-appearance:none;
  font-family:var(--font-sans);font-size:var(--text-md);color:var(--text-primary);
  background:var(--surface-card);border:var(--border-width-hairline) solid var(--border-default);
  border-radius:var(--radius-md);padding:10px 36px 10px 12px;outline:none;cursor:pointer;
  transition:var(--transition-colors),box-shadow var(--duration-base) var(--ease-standard);}
.wc-select:hover{border-color:var(--stone-400);}
.wc-select:focus{border-color:var(--brand);box-shadow:0 0 0 3px var(--ring-brand);}`;
  document.head.appendChild(el);
}

/**
 * Native select with the brand chrome. Pass `options` (string[] or
 * {value,label}[]) or children <option>s. Optional `label` above.
 */
export function Select({ label, options, children, id, style, className = "", containerStyle, ...rest }) {
  ensureSelectStyles();
  const fieldId = id || (label ? `wc-${label.replace(/\s+/g, "-").toLowerCase()}` : undefined);
  const opts = (options || []).map((o) =>
    typeof o === "string" ? { value: o, label: o } : o
  );
  const control = (
    <div className="wc-select-wrap">
      <select id={fieldId} className={`wc-select ${className}`.trim()} style={style} {...rest}>
        {opts.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
        {children}
      </select>
      <i className="ti ti-chevron-down" aria-hidden="true" />
    </div>
  );
  if (!label) return control;
  return (
    <label className="wc-field" htmlFor={fieldId} style={containerStyle}>
      <span className="wc-field__label">{label}</span>
      {control}
    </label>
  );
}
