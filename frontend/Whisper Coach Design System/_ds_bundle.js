/* @ds-bundle: {"format":3,"namespace":"WhisperCoachDesignSystem_6c0cf7","components":[{"name":"ChatBubble","sourcePath":"components/chat/ChatBubble.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Chip","sourcePath":"components/core/Chip.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"Tag","sourcePath":"components/core/Tag.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"UploadZone","sourcePath":"components/forms/UploadZone.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"},{"name":"Pitch","sourcePath":"components/pitch/Pitch.jsx"},{"name":"PlayerDot","sourcePath":"components/pitch/PlayerDot.jsx"}],"sourceHashes":{"components/chat/ChatBubble.jsx":"79ce0c36cd35","components/core/Badge.jsx":"d5f5a333ac91","components/core/Button.jsx":"8e2bd5706762","components/core/Card.jsx":"e48b7df20430","components/core/Chip.jsx":"be55e3a7c5da","components/core/IconButton.jsx":"af94a767b482","components/core/Tag.jsx":"3a55827ac3f9","components/forms/Input.jsx":"44d13d44b8f1","components/forms/Select.jsx":"aaa2e459725a","components/forms/UploadZone.jsx":"87226df2baed","components/navigation/TabBar.jsx":"11bd61329118","components/pitch/Pitch.jsx":"e723d3ffcb07","components/pitch/PlayerDot.jsx":"32a017c87768"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.WhisperCoachDesignSystem_6c0cf7 = window.WhisperCoachDesignSystem_6c0cf7 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/chat/ChatBubble.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function ChatBubble({
  role = "assistant",
  from = "Whisper Coach",
  time,
  lead,
  children,
  style,
  className = "",
  ...rest
}) {
  ensureChatStyles();
  if (role === "user") {
    return /*#__PURE__*/React.createElement("div", _extends({
      className: `wc-bubble wc-bubble--user ${className}`.trim(),
      style: style
    }, rest), children);
  }
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `wc-bubble wc-bubble--assistant ${className}`.trim(),
    style: style
  }, rest), /*#__PURE__*/React.createElement("div", {
    className: "wc-bubble__from"
  }, /*#__PURE__*/React.createElement("i", {
    className: "ti ti-cpu",
    "aria-hidden": "true"
  }), from, time ? ` · ${time}` : ""), /*#__PURE__*/React.createElement("div", null, lead && /*#__PURE__*/React.createElement("span", {
    className: "wc-bubble__lead"
  }, lead, " "), children));
}
Object.assign(__ds_scope, { ChatBubble });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/chat/ChatBubble.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Small count / notification marker. Use `dot` for a bare status dot,
 * or pass a number/short label for a count badge (e.g. squad size,
 * unread events).
 */
function Badge({
  children,
  tone = "brand",
  dot = false,
  style,
  className = "",
  ...rest
}) {
  const tones = {
    brand: {
      bg: "var(--brand)",
      fg: "var(--text-on-brand)"
    },
    neutral: {
      bg: "var(--stone-300)",
      fg: "var(--ink-700)"
    },
    danger: {
      bg: "var(--red-700)",
      fg: "#fff"
    }
  };
  const t = tones[tone] || tones.brand;
  const base = {
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    fontFamily: "var(--font-sans)",
    fontWeight: "var(--weight-semibold)",
    background: t.bg,
    color: t.fg,
    ...style
  };
  if (dot) {
    return /*#__PURE__*/React.createElement("span", _extends({
      className: `wc-badge wc-badge--dot ${className}`.trim(),
      style: {
        ...base,
        width: 8,
        height: 8,
        borderRadius: "var(--radius-pill)"
      }
    }, rest));
  }
  return /*#__PURE__*/React.createElement("span", _extends({
    className: `wc-badge ${className}`.trim(),
    style: {
      ...base,
      minWidth: 18,
      height: 18,
      padding: "0 5px",
      fontSize: 11,
      lineHeight: 1,
      borderRadius: "var(--radius-pill)"
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
  sm: {
    padding: "7px 12px",
    fontSize: "var(--text-sm)",
    icon: 14
  },
  md: {
    padding: "9px 16px",
    fontSize: "var(--text-md)",
    icon: 16
  },
  lg: {
    padding: "13px 16px",
    fontSize: "var(--text-lg)",
    icon: 17
  }
};

/**
 * Primary action button. The green primary is the app's main CTA
 * ("Generate lineup", "Start match"); secondary/ghost are quieter.
 */
function Button({
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
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    className: cls,
    disabled: disabled,
    onClick: onClick,
    style: {
      padding: s.padding,
      fontSize: s.fontSize,
      ...style
    }
  }, rest), icon && /*#__PURE__*/React.createElement("i", {
    className: `ti ti-${icon}`,
    style: {
      fontSize: s.icon
    },
    "aria-hidden": "true"
  }), children, iconRight && /*#__PURE__*/React.createElement("i", {
    className: `ti ti-${iconRight}`,
    style: {
      fontSize: s.icon
    },
    "aria-hidden": "true"
  }));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * The workhorse surface: white, hairline border, lg radius. Holds form
 * sections, AI reasoning blocks, list groups. Set `tinted` for the soft
 * green AI/reasoning style, `sunken` for the secondary-fill style.
 */
function Card({
  children,
  tinted = false,
  sunken = false,
  padding,
  onClick,
  style,
  className = "",
  ...rest
}) {
  const bg = tinted ? "var(--brand-subtle)" : sunken ? "var(--surface-sunken)" : "var(--surface-card)";
  const border = tinted ? "var(--brand-border)" : "var(--border-subtle)";
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `wc-card ${className}`.trim(),
    onClick: onClick,
    style: {
      background: bg,
      border: `var(--border-width-hairline) solid ${border}`,
      borderRadius: "var(--radius-lg)",
      padding: padding != null ? padding : "var(--pad-card) var(--pad-card-x)",
      cursor: onClick ? "pointer" : "default",
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Chip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function Chip({
  children,
  selected = false,
  icon,
  onClick,
  style,
  className = "",
  ...rest
}) {
  ensureChipStyles();
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: `wc-chip${selected ? " is-selected" : ""} ${className}`.trim(),
    "aria-pressed": selected,
    onClick: onClick,
    style: style
  }, rest), icon && /*#__PURE__*/React.createElement("i", {
    className: `ti ti-${icon}`,
    style: {
      fontSize: 14
    },
    "aria-hidden": "true"
  }), children);
}
Object.assign(__ds_scope, { Chip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Chip.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
const IB_SIZES = {
  sm: 32,
  md: 38,
  lg: 44
};

/**
 * A square (or round) tappable icon — the mic / send controls in the
 * live-match composer, toolbar actions, etc.
 */
function IconButton({
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
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: cls,
    disabled: disabled,
    onClick: onClick,
    "aria-label": label,
    style: {
      width: dim,
      height: dim,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("i", {
    className: `ti ti-${recording ? "player-stop" : icon}`,
    style: {
      fontSize: Math.round(dim * 0.46)
    },
    "aria-hidden": "true"
  }));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/Tag.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TAG_TONES = {
  green: {
    bg: "var(--success-bg)",
    fg: "var(--success-fg)"
  },
  amber: {
    bg: "var(--warning-bg)",
    fg: "var(--warning-fg)"
  },
  red: {
    bg: "var(--danger-bg)",
    fg: "var(--danger-fg)"
  },
  neutral: {
    bg: "var(--surface-sunken)",
    fg: "var(--text-secondary)"
  },
  inverse: {
    bg: "var(--surface-inverse)",
    fg: "var(--text-on-inverse)"
  }
};

/**
 * Soft status pill — player availability, match state, the little "AI"
 * marker. Tone maps to the tactical color set.
 */
function Tag({
  children,
  tone = "green",
  icon,
  style,
  className = "",
  ...rest
}) {
  const t = TAG_TONES[tone] || TAG_TONES.green;
  return /*#__PURE__*/React.createElement("span", _extends({
    className: `wc-tag ${className}`.trim(),
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 4,
      fontFamily: "var(--font-sans)",
      fontSize: "var(--text-xs)",
      fontWeight: "var(--weight-medium)",
      lineHeight: 1,
      padding: "4px 10px",
      borderRadius: "var(--radius-pill)",
      background: t.bg,
      color: t.fg,
      ...style
    }
  }, rest), icon && /*#__PURE__*/React.createElement("i", {
    className: `ti ti-${icon}`,
    style: {
      fontSize: 12
    },
    "aria-hidden": "true"
  }), children);
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tag.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function Input({
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
  const control = multiline ? /*#__PURE__*/React.createElement("textarea", _extends({
    id: fieldId,
    className: `wc-input ${className}`.trim(),
    rows: rows,
    style: style
  }, rest)) : /*#__PURE__*/React.createElement("input", _extends({
    id: fieldId,
    className: `wc-input ${className}`.trim(),
    style: style
  }, rest));
  if (!label) return control;
  return /*#__PURE__*/React.createElement("label", {
    className: "wc-field",
    htmlFor: fieldId,
    style: containerStyle
  }, /*#__PURE__*/React.createElement("span", {
    className: "wc-field__label"
  }, label), control);
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function Select({
  label,
  options,
  children,
  id,
  style,
  className = "",
  containerStyle,
  ...rest
}) {
  ensureSelectStyles();
  const fieldId = id || (label ? `wc-${label.replace(/\s+/g, "-").toLowerCase()}` : undefined);
  const opts = (options || []).map(o => typeof o === "string" ? {
    value: o,
    label: o
  } : o);
  const control = /*#__PURE__*/React.createElement("div", {
    className: "wc-select-wrap"
  }, /*#__PURE__*/React.createElement("select", _extends({
    id: fieldId,
    className: `wc-select ${className}`.trim(),
    style: style
  }, rest), opts.map(o => /*#__PURE__*/React.createElement("option", {
    key: o.value,
    value: o.value
  }, o.label)), children), /*#__PURE__*/React.createElement("i", {
    className: "ti ti-chevron-down",
    "aria-hidden": "true"
  }));
  if (!label) return control;
  return /*#__PURE__*/React.createElement("label", {
    className: "wc-field",
    htmlFor: fieldId,
    style: containerStyle
  }, /*#__PURE__*/React.createElement("span", {
    className: "wc-field__label"
  }, label), control);
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/UploadZone.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const UPLOAD_STYLE_ID = "wc-upload-styles";
function ensureUploadStyles() {
  if (typeof document === "undefined" || document.getElementById(UPLOAD_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = UPLOAD_STYLE_ID;
  el.textContent = `
.wc-upload{display:block;width:100%;box-sizing:border-box;text-align:center;cursor:pointer;
  font-family:var(--font-sans);background:var(--surface-card);
  border:1px dashed var(--border-default);border-radius:var(--radius-lg);
  padding:28px 16px;transition:var(--transition-colors);}
.wc-upload:hover{background:var(--surface-sunken);}
.wc-upload .wc-upload__icon{font-size:32px;color:var(--text-tertiary);display:block;margin-bottom:8px;}
.wc-upload__title{font-size:var(--text-md);font-weight:var(--weight-medium);color:var(--text-primary);}
.wc-upload__hint{font-size:var(--text-sm);color:var(--text-secondary);margin-top:4px;}
.wc-upload.is-done{background:var(--brand-subtle);border-color:var(--brand-border);border-style:solid;}
.wc-upload.is-done .wc-upload__icon,.wc-upload.is-done .wc-upload__title{color:var(--brand);}
.wc-upload__spin{display:inline-block;animation:wc-spin 0.8s linear infinite;}
@keyframes wc-spin{to{transform:rotate(360deg);}}
@media (prefers-reduced-motion:reduce){.wc-upload__spin{animation:none;}}`;
  document.head.appendChild(el);
}
const UPLOAD_COPY = {
  idle: {
    icon: "camera",
    title: "Upload team roster photo",
    hint: "AI will extract player names automatically"
  },
  processing: {
    icon: "loader-2",
    title: "Reading roster…",
    hint: "Extracting player names"
  },
  done: {
    icon: "circle-check",
    title: "Photo processed!",
    hint: "players detected"
  }
};

/**
 * Dashed photo-upload target for the "extract roster" flow. Drive the
 * three states with `status`; on `done` it shows the detected count.
 */
function UploadZone({
  status = "idle",
  count,
  title,
  hint,
  onClick,
  style,
  className = "",
  ...rest
}) {
  ensureUploadStyles();
  const c = UPLOAD_COPY[status] || UPLOAD_COPY.idle;
  const resolvedHint = hint != null ? hint : status === "done" && count != null ? `${count} ${c.hint}` : c.hint;
  return /*#__PURE__*/React.createElement("div", _extends({
    role: "button",
    tabIndex: 0,
    className: `wc-upload${status === "done" ? " is-done" : ""} ${className}`.trim(),
    onClick: onClick,
    style: style
  }, rest), /*#__PURE__*/React.createElement("i", {
    className: `ti ti-${c.icon} wc-upload__icon${status === "processing" ? " wc-upload__spin" : ""}`,
    "aria-hidden": "true"
  }), /*#__PURE__*/React.createElement("div", {
    className: "wc-upload__title"
  }, title || c.title), /*#__PURE__*/React.createElement("div", {
    className: "wc-upload__hint"
  }, resolvedHint));
}
Object.assign(__ds_scope, { UploadZone });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/UploadZone.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function TabBar({
  items = [],
  value,
  onChange,
  style,
  className = "",
  ...rest
}) {
  ensureTabBarStyles();
  return /*#__PURE__*/React.createElement("nav", _extends({
    className: `wc-tabbar ${className}`.trim(),
    style: {
      gridTemplateColumns: `repeat(${items.length}, 1fr)`,
      ...style
    }
  }, rest), items.map(it => /*#__PURE__*/React.createElement("button", {
    key: it.key,
    type: "button",
    className: `wc-tab${value === it.key ? " is-active" : ""}`,
    "aria-current": value === it.key ? "page" : undefined,
    onClick: () => onChange && onChange(it.key)
  }, /*#__PURE__*/React.createElement("i", {
    className: `ti ti-${it.icon}`,
    "aria-hidden": "true"
  }), it.label)));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// components/pitch/PlayerDot.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
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
function PlayerDot({
  name,
  pos,
  x,
  y,
  size = 38,
  selected = false,
  onClick,
  style,
  className = "",
  ...rest
}) {
  ensurePlayerDotStyles();
  const positioned = x != null && y != null;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    className: `wc-dot${selected ? " is-selected" : ""} ${className}`.trim(),
    onClick: onClick,
    style: {
      width: size,
      height: size,
      ...(positioned ? {
        left: `${x}%`,
        top: `${y}%`,
        position: "absolute"
      } : {
        position: "relative",
        transform: "none"
      }),
      ...style
    }
  }, rest), name && /*#__PURE__*/React.createElement("span", {
    className: "wc-dot__name"
  }, name), pos && /*#__PURE__*/React.createElement("span", {
    className: "wc-dot__pos"
  }, pos));
}
Object.assign(__ds_scope, { PlayerDot });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/pitch/PlayerDot.jsx", error: String((e && e.message) || e) }); }

// components/pitch/Pitch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const PITCH_STYLE_ID = "wc-pitch-styles";
function ensurePitchStyles() {
  if (typeof document === "undefined" || document.getElementById(PITCH_STYLE_ID)) return;
  const el = document.createElement("style");
  el.id = PITCH_STYLE_ID;
  el.textContent = `
.wc-pitch{position:relative;border-radius:var(--radius-md);overflow:hidden;
  background:var(--surface-pitch);font-family:var(--font-sans);}
.wc-pitch__stripes{position:absolute;inset:0;
  background:repeating-linear-gradient(0deg,var(--pitch-400) 0 9%,var(--pitch-600) 9% 18%);opacity:.22;}
.wc-pitch__line{position:absolute;border:1.5px solid var(--pitch-line);}
.wc-pitch__circle{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
  width:60px;height:60px;border-radius:50%;border:1.5px solid var(--pitch-line);}
.wc-pitch__spot{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);
  width:4px;height:4px;border-radius:50%;background:var(--pitch-line);}
.wc-pitch__badge{position:absolute;bottom:12px;right:12px;display:inline-flex;align-items:center;gap:4px;
  background:var(--surface-inverse);color:var(--text-on-inverse);font-size:var(--text-xs);
  font-weight:var(--weight-medium);padding:4px 10px;border-radius:var(--radius-pill);}
.wc-pitch__badge .ti{font-size:11px;}`;
  document.head.appendChild(el);
}

/**
 * The playing field. Renders turf, markings and a set of `players`
 * ([{id,name,pos,x,y}]) as PlayerDots. Vertical orientation with the GK
 * at the bottom — matching the lineup screen.
 */
function Pitch({
  players = [],
  selectedId,
  onSelectPlayer,
  height = 380,
  aiBadge = false,
  dotSize = 38,
  style,
  className = "",
  children,
  ...rest
}) {
  ensurePitchStyles();
  return /*#__PURE__*/React.createElement("div", _extends({
    className: `wc-pitch ${className}`.trim(),
    style: {
      height,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    className: "wc-pitch__stripes"
  }), /*#__PURE__*/React.createElement("div", {
    className: "wc-pitch__line",
    style: {
      top: "3%",
      left: "6%",
      width: "88%",
      height: "94%",
      borderRadius: 3
    }
  }), /*#__PURE__*/React.createElement("div", {
    className: "wc-pitch__line",
    style: {
      top: "3%",
      left: "30%",
      width: "40%",
      height: "14%"
    }
  }), /*#__PURE__*/React.createElement("div", {
    className: "wc-pitch__line",
    style: {
      bottom: "3%",
      left: "30%",
      width: "40%",
      height: "14%"
    }
  }), /*#__PURE__*/React.createElement("div", {
    className: "wc-pitch__line",
    style: {
      top: "50%",
      left: "6%",
      width: "88%",
      height: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    className: "wc-pitch__circle"
  }), /*#__PURE__*/React.createElement("div", {
    className: "wc-pitch__spot"
  }), players.map(p => /*#__PURE__*/React.createElement(__ds_scope.PlayerDot, {
    key: p.id,
    name: p.name,
    pos: p.pos,
    x: p.x,
    y: p.y,
    size: dotSize,
    selected: selectedId === p.id,
    onClick: () => onSelectPlayer && onSelectPlayer(p.id)
  })), children, aiBadge && /*#__PURE__*/React.createElement("span", {
    className: "wc-pitch__badge"
  }, /*#__PURE__*/React.createElement("i", {
    className: "ti ti-cpu",
    "aria-hidden": "true"
  }), "AI generated"));
}
Object.assign(__ds_scope, { Pitch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/pitch/Pitch.jsx", error: String((e && e.message) || e) }); }

__ds_ns.ChatBubble = __ds_scope.ChatBubble;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Chip = __ds_scope.Chip;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.UploadZone = __ds_scope.UploadZone;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.Pitch = __ds_scope.Pitch;

__ds_ns.PlayerDot = __ds_scope.PlayerDot;

})();
