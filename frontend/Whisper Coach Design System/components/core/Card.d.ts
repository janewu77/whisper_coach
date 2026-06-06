import React from "react";

export interface CardProps {
  children?: React.ReactNode;
  /** Soft green fill + green hairline — the AI / reasoning style. */
  tinted?: boolean;
  /** Neutral stone fill instead of white. */
  sunken?: boolean;
  /** Override inner padding (number = px, or any CSS padding string). */
  padding?: number | string;
  onClick?: (e: React.MouseEvent<HTMLDivElement>) => void;
  style?: React.CSSProperties;
  className?: string;
}

/** Hairline-bordered surface for grouped content. */
export function Card(props: CardProps): JSX.Element;
