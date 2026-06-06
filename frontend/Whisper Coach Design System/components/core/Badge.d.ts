import React from "react";

export interface BadgeProps {
  /** Count or short label. Omit when `dot`. */
  children?: React.ReactNode;
  /** @default "brand" */
  tone?: "brand" | "neutral" | "danger";
  /** Render a bare 8px status dot instead of a count. */
  dot?: boolean;
  style?: React.CSSProperties;
  className?: string;
}

/** Small count / notification marker or status dot. */
export function Badge(props: BadgeProps): JSX.Element;
