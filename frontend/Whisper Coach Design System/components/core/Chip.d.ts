import React from "react";

export interface ChipProps {
  children?: React.ReactNode;
  /** Selected (active) state — green tint. */
  selected?: boolean;
  /** Optional leading Tabler icon name (without `ti-`). */
  icon?: string;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  style?: React.CSSProperties;
  className?: string;
}

/** Selectable pill for formation pickers, filters and segmented options. */
export function Chip(props: ChipProps): JSX.Element;
