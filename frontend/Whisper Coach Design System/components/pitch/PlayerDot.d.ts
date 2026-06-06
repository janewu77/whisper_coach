import React from "react";

export interface PlayerDotProps {
  /** Initials / short name shown on the dot, e.g. "H.Y". */
  name?: string;
  /** Position label under the name, e.g. "GK", "CB". */
  pos?: string;
  /** Horizontal position on the pitch, 0–100 (%). */
  x?: number;
  /** Vertical position on the pitch, 0–100 (%). */
  y?: number;
  /** Diameter in px. @default 38 */
  size?: number;
  selected?: boolean;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  style?: React.CSSProperties;
  className?: string;
}

/** A single positioned player token, used inside <Pitch>. */
export function PlayerDot(props: PlayerDotProps): JSX.Element;
