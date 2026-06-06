import React from "react";

const TAG_TONES = {
  green: { bg: "var(--success-bg)", fg: "var(--success-fg)" },
  amber: { bg: "var(--warning-bg)", fg: "var(--warning-fg)" },
  red: { bg: "var(--danger-bg)", fg: "var(--danger-fg)" },
  neutral: { bg: "var(--surface-sunken)", fg: "var(--text-secondary)" },
  inverse: { bg: "var(--surface-inverse)", fg: "var(--text-on-inverse)" },
};

/**
 * Soft status pill — player availability, match state, the little "AI"
 * marker. Tone maps to the tactical color set.
 */
export function Tag({ children, tone = "green", icon, style, className = "", ...rest }) {
  const t = TAG_TONES[tone] || TAG_TONES.green;
  return (
    <span
      className={`wc-tag ${className}`.trim()}
      style={{
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
        ...style,
      }}
      {...rest}
    >
      {icon && <i className={`ti ti-${icon}`} style={{ fontSize: 12 }} aria-hidden="true" />}
      {children}
    </span>
  );
}
