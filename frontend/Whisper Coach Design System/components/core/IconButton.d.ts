import React from "react";

export interface IconButtonProps {
  /** Tabler icon name without the `ti-` prefix, e.g. "microphone". */
  icon: string;
  /** @default "neutral" */
  variant?: "solid" | "neutral" | "ghost";
  /** @default "md" */
  size?: "sm" | "md" | "lg";
  /** Use a fully-rounded (pill/circle) shape. */
  round?: boolean;
  /** Show the recording state (red fill, stop glyph) — used by the mic. */
  recording?: boolean;
  disabled?: boolean;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  /** Accessible label (required, since there's no visible text). */
  label?: string;
  style?: React.CSSProperties;
  className?: string;
}

/** Square or round icon-only button (mic, send, toolbar actions). */
export function IconButton(props: IconButtonProps): JSX.Element;
