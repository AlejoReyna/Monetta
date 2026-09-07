import type { PollStatus } from '../api/poll.js';

/** The one banner rule: unreachable must say so loudly, never look healthy. */
export function ConnectionBanner(props: {
  readonly status: PollStatus;
  readonly lastOkAt: Date | null;
  readonly now?: () => Date;
}): JSX.Element | null {
  if (props.status === 'ok') return null;
  const when = props.lastOkAt !== null
    ? `Last successful poll ${props.lastOkAt.toISOString()}.`
    : 'No successful poll yet.';
  return (
    <div role="status" aria-live="polite">
      {props.status === 'degraded' ? '● degraded' : '■ unreachable'}
      {` — showing last-known data. ${when}`}
    </div>
  );
}
