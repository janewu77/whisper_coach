import React from "react";

/**
 * Bottom tab navigation for the mobile app.
 * @startingPoint section="Navigation" subtitle="Bottom tab bar" viewport="390x80"
 */
export interface TabBarProps {
  items: TabItem[];
  /** Active tab key. */
  value?: string;
  onChange?: (key: string) => void;
  style?: React.CSSProperties;
  className?: string;
}

export interface TabItem {
  /** Unique key / value for the tab. */
  key: string;
  /** Visible label under the icon. */
  label: string;
  /** Tabler icon name without `ti-`. */
  icon: string;
}

/** Bottom tab navigation for the mobile app. */
export function TabBar(props: TabBarProps): JSX.Element;
