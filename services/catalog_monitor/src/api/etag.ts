import { createHash } from 'node:crypto';

/** A strong ETag over the exact bytes returned — sufficient here since the payload is small JSON, not a huge stream. */
export function computeEtag(body: string): string {
  const hash = createHash('sha256').update(body).digest('hex').slice(0, 32);
  return `"${hash}"`;
}
