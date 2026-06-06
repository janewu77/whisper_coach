import React from "react";

export interface InputProps extends Omit<React.InputHTMLAttributes<HTMLInputElement>, "style"> {
  /** Field label rendered above the control. */
  label?: string;
  /** Render a <textarea> instead of <input>. */
  multiline?: boolean;
  /** Rows for the textarea. @default 3 */
  rows?: number;
  style?: React.CSSProperties;
  className?: string;
  /** Style for the wrapping <label> when `label` is set. */
  containerStyle?: React.CSSProperties;
}

/** Labelled text input / textarea with brand focus ring. */
export function Input(props: InputProps): JSX.Element;
