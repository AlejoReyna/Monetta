/** Status is never colour alone — every state carries a label and glyph. */
const GLYPH: Record<string, string> = {
  healthy: '●',
  unhealthy: '▲',
  degraded: '◐',
  unreachable: '■',
  blocked: '■',
  success: '●',
  partial: '◐',
  failed: '▲',
  running: '…',
};

export function StatusBadge(props: { readonly status: string }): JSX.Element {
  const glyph = GLYPH[props.status] ?? '○';
  return (
    <span aria-label={`status: ${props.status}`}>
      {glyph} {props.status}
    </span>
  );
}
