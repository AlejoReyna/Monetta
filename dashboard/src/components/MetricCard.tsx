import type { ReactNode } from 'react';

/** Dense metric tile: tabular numerals, label always adjacent. */
export function MetricCard(props: {
  readonly label: string;
  readonly value: ReactNode;
  readonly sub?: ReactNode;
}): JSX.Element {
  return (
    <div className="metric-card" style={{ fontVariantNumeric: 'tabular-nums' }}>
      <div className="metric-card__label">{props.label}</div>
      <div className="metric-card__value">{props.value}</div>
      {props.sub !== undefined && <div className="metric-card__sub">{props.sub}</div>}
    </div>
  );
}
