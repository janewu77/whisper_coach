import React from "react";

export interface TagProps {
  children?: React.ReactNode;
  /** Tactical tone. @default "green" */
  tone?: "green" | "amber" | "red" | "neutral" | "inverse";
  /** Optional leading Tabler icon name (without `ti-`). */
  icon?: string;
  style?: React.CSSProperties;
  className?: string;
}

/** Soft status pill (player availability, match state, AI marker). */
export function Tag(props: TagProps): JSX.Element;
