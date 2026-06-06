import React from "react";

export interface SelectOption {
  value: string;
  label: string;
}

export interface SelectProps extends Omit<React.SelectHTMLAttributes<HTMLSelectElement>, "style"> {
  /** Field label rendered above the control. */
  label?: string;
  /** Options as strings or {value,label} objects. */
  options?: Array<string | SelectOption>;
  style?: React.CSSProperties;
  className?: string;
  containerStyle?: React.CSSProperties;
}

/** Native select styled with brand chrome and a chevron. */
export function Select(props: SelectProps): JSX.Element;
