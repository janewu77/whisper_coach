import React from "react";

/**
 * Small count / notification marker. Use `dot` for a bare status dot,
 * or pass a number/short label for a count badge (e.g. squad size,
 * unread events).
 */
export function Badge({ children, tone = "brand", dot = false, style, className = "", ...rest }) {
  const tones = {
    brand: { bg: "var(--brand)", fg: "var(--text-on-brand)" },
    neutral: { bg: "var(--stone-300)", fg: "var(--ink-700)" },
    danger: { bg: "var(--red-700)", fg: "#fff" },
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
    ...style,
  };
  if (dot) {
    return <span className={`wc-badge wc-badge--dot ${className}`.trim()} style={{ ...base, width: 8, height: 8, borderRadius: "var(--radius-pill)" }} {...rest} />;
  }
  return (
    <span
      className={`wc-badge ${className}`.trim()}
      style={{
        ...base,
        minWidth: 18,
        height: 18,
        padding: "0 5px",
        fontSize: 11,
        lineHeight: 1,
        borderRadius: "var(--radius-pill)",
      }}
      {...rest}
    >
      {children}
    </span>
  );
}
