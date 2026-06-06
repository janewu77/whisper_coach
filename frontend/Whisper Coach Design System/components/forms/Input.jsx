import React from "react";

const FIELD_STYLE_ID = "wc-field-styles";
function ensureFieldStyles() {
  if (typeof document === "undefined" || document.getElementById(FIELD_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = FIELD_STYLE_ID;
  el.textContent = `
.wc-field{display:block;font-family:var(--font-sans);}
.wc-field__label{display:block;font-size:var(--text-base);color:var(--text-secondary);margin-bottom:6px;}
.wc-input{width:100%;box-sizing:border-box;font-family:var(--font-sans);
  font-size:var(--text-md);color:var(--text-primary);background:var(--surface-card);
  border:var(--border-width-hairline) solid var(--border-default);border-radius:var(--radius-md);
  padding:10px 12px;outline:none;transition:var(--transition-colors),box-shadow var(--duration-base) var(--ease-standard);}
.wc-input::placeholder{color:var(--text-tertiary);}
.wc-input:hover{border-color:var(--stone-400);}
.wc-input:focus{border-color:var(--brand);box-shadow:0 0 0 3px var(--ring-brand);}
.wc-input:disabled{background:var(--surface-sunken);color:var(--text-tertiary);cursor:not-allowed;}
textarea.wc-input{resize:vertical;line-height:var(--leading-normal);}`;
  document.head.appendChild(el);
}

/**
 * Text input / textarea with an optional label. Set `multiline` (and
 * `rows`) for the notes-style field.
 */
export function Input({
  label,
  multiline = false,
  rows = 3,
  id,
  style,
  className = "",
  containerStyle,
  ...rest
}) {
  ensureFieldStyles();
  const fieldId = id || (label ? `wc-${label.replace(/\s+/g, "-").toLowerCase()}` : undefined);
  const control = multiline ? (
    <textarea id={fieldId} className={`wc-input ${className}`.trim()} rows={rows} style={style} {...rest} />
  ) : (
    <input id={fieldId} className={`wc-input ${className}`.trim()} style={style} {...rest} />
  );
  if (!label) return control;
  return (
    <label className="wc-field" htmlFor={fieldId} style={containerStyle}>
      <span className="wc-field__label">{label}</span>
      {control}
    </label>
  );
}
