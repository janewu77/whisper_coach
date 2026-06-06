import React from "react";

export interface ChatBubbleProps {
  /** @default "assistant" */
  role?: "assistant" | "user";
  /** Sender label for assistant bubbles. @default "Whisper Coach" */
  from?: string;
  /** Timestamp suffix shown after the sender (e.g. "23'"). */
  time?: string;
  /** Bold lead-in for assistant messages, e.g. "Suggestion:". */
  lead?: string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
  className?: string;
}

/** One message in the live-match coaching log (AI card or user bubble). */
export function ChatBubble(props: ChatBubbleProps): JSX.Element;
