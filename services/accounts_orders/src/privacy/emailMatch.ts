/** Trimmed, lowercased account email. Empty input does not match anything. */
export function normalizeAccountEmail(value: string | null | undefined): string | null {
  if (value == null) return null;
  const normalized = value.trim().toLowerCase();
  return normalized === '' ? null : normalized;
}

/**
 * First character, three bullets, then `@domain`.
 * `Alexis@Gmail.com` becomes `a•••@gmail.com`.
 */
export function maskAccountEmail(value: string): string {
  const normalized = normalizeAccountEmail(value) ?? '';
  const at = normalized.lastIndexOf('@');
  const first = normalized[0] ?? '';
  if (at <= 0) return `${first}•••`;
  return `${first}•••${normalized.slice(at)}`;
}
