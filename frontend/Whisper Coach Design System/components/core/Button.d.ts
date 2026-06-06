import React from "react";

/**
 * Props for the primary action button.
 * @startingPoint section="Core" subtitle="Primary / secondary / ghost actions" viewport="700x150"
 */
export interface ButtonProps {
  /** Button label / content. */
  children?: React.ReactNode;
  /** Visual style. `primary` is the green CTA. @default "primary" */
  variant?: "primary" | "secondary" | "subtle" | "ghost" | "danger";
  /** Size. @default "md" */
  size?: "sm" | "md" | "lg";
  /** Stretch to fill the container width (used for the main screen CTA). */
  fullWidth?: boolean;
  /** Tabler icon name (without `ti-`) shown before the label, e.g. "wand". */
  icon?: string;
  /** Tabler icon name shown after the label. */
  iconRight?: string;
  disabled?: boolean;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  type?: "button" | "submit" | "reset";
  style?: React.CSSProperties;
  className?: string;
}

/** The primary action button for Whisper Coach. */
export function Button(props: ButtonProps): JSX.Element;
