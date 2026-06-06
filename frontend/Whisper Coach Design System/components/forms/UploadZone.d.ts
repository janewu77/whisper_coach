import React from "react";

export interface UploadZoneProps {
  /** Flow state. @default "idle" */
  status?: "idle" | "processing" | "done";
  /** Number of detected players (shown in the `done` hint). */
  count?: number;
  /** Override the title line. */
  title?: string;
  /** Override the hint line. */
  hint?: string;
  onClick?: (e: React.MouseEvent<HTMLDivElement>) => void;
  style?: React.CSSProperties;
  className?: string;
}

/** Dashed photo-upload target for the AI roster-extraction flow. */
export function UploadZone(props: UploadZoneProps): JSX.Element;
