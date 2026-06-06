import React from "react";

/**
 * Props for the signature tactical pitch.
 * @startingPoint section="Pitch" subtitle="Lineup field with players" viewport="360x420"
 */
export interface PitchProps {
  players?: PitchPlayer[];
  /** Currently-selected player id. */
  selectedId?: string;
  onSelectPlayer?: (id: string) => void;
  /** Pitch height in px. @default 380 */
  height?: number;
  /** Show the dark "AI generated" badge bottom-right. */
  aiBadge?: boolean;
  /** Player dot diameter. @default 38 */
  dotSize?: number;
  children?: React.ReactNode;
  style?: React.CSSProperties;
  className?: string;
}

export interface PitchPlayer {
  id: string;
  /** Initials shown on the dot, e.g. "H.Y". */
  name: string;
  /** Position label, e.g. "GK", "ST". */
  pos: string;
  /** 0–100 (%) horizontal. */
  x: number;
  /** 0–100 (%) vertical (GK near 88, strikers near 22). */
  y: number;
}

/** The signature tactical pitch with positioned players. */
export function Pitch(props: PitchProps): JSX.Element;
