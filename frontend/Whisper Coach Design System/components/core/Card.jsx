import React from "react";

/**
 * The workhorse surface: white, hairline border, lg radius. Holds form
 * sections, AI reasoning blocks, list groups. Set `tinted` for the soft
 * green AI/reasoning style, `sunken` for the secondary-fill style.
 */
export function Card({
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
  return (
    <div
      className={`wc-card ${className}`.trim()}
      onClick={onClick}
      style={{
        background: bg,
        border: `var(--border-width-hairline) solid ${border}`,
        borderRadius: "var(--radius-lg)",
        padding: padding != null ? padding : "var(--pad-card) var(--pad-card-x)",
        cursor: onClick ? "pointer" : "default",
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}
