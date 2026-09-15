/** Inline-SVG coverage sparkline. No chart library — tables, numbers, one editor. */
export function Sparkline(props: { readonly values: ReadonlyArray<number | null> }): JSX.Element {
  const width = 100;
  const height = 28;
  const points = props.values.filter((v): v is number => v !== null);
  if (points.length < 2) {
    return (
      <svg width={width} height={height} role="img" aria-label="coverage trend (insufficient data)" />
    );
  }
  const min = Math.min(...points, 0);
  const max = Math.max(...points, 1);
  const span = max - min === 0 ? 1 : max - min;
  const step = width / (points.length - 1);
  const coords = points
    .map((v, i) => `${(i * step).toFixed(1)},${(height - 2 - ((v - min) / span) * (height - 4)).toFixed(1)}`)
    .join(' ');
  return (
    <svg width={width} height={height} role="img" aria-label={`coverage trend, last ${points.length} runs`}>
      <polyline points={coords} fill="none" stroke="currentColor" strokeWidth="1.5" />
    </svg>
  );
}
