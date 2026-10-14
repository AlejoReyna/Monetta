/**
 * Account-deletion logs and audit rows may carry internal ids, step codes,
 * and a timestamp. Email, address, and payment data are stripped before
 * anything is written.
 */

const forbiddenKey =
  /email|e-mail|address|phone|payment|card|cvv|pan|iban|name|token|password|secret|street|postal|zip|city|country/i;

const emailPattern = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const cardPattern = /\b(?:\d[ -]*?){13,19}\b/g;

const allowedStepValues = new Set([
  'not_attempted',
  'deleted',
  'absent',
  'anonymized',
  'requested',
  'failed',
  'blocked',
  'skipped',
  'pending',
]);

export function redactText(value: string): string {
  return value
    .replace(emailPattern, '[redacted]')
    .replace(cardPattern, '[redacted]');
}

export function redactLogFields(
  fields: Record<string, unknown> | undefined,
): Record<string, unknown> | undefined {
  if (fields === undefined) return undefined;
  return redactValue(fields) as Record<string, unknown>;
}

function redactValue(value: unknown): unknown {
  if (typeof value === 'string') return redactText(value);
  if (typeof value === 'number' || typeof value === 'boolean' || value === null) {
    return value;
  }
  if (Array.isArray(value)) return value.map((entry) => redactValue(entry));
  if (typeof value === 'object') {
    const redacted: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value)) {
      if (forbiddenKey.test(key)) continue;
      redacted[key] = redactValue(entry);
    }
    return redacted;
  }
  return undefined;
}

export function sanitizeAuditSteps(
  steps: Record<string, string>,
): Record<string, string> {
  const sanitized: Record<string, string> = {};
  for (const [key, value] of Object.entries(steps)) {
    if (forbiddenKey.test(key)) continue;
    if (!/^[a-z][a-zA-Z0-9]{0,40}$/.test(key)) continue;
    sanitized[key] = allowedStepValues.has(value) ? value : 'failed';
  }
  return sanitized;
}

const internalId = /^[A-Za-z0-9:._/-]{1,200}$/;

export function sanitizeInternalId(value: string | null | undefined): string | null {
  if (value === null || value === undefined) return null;
  const trimmed = value.trim();
  if (trimmed === '' || trimmed.includes('@') || !internalId.test(trimmed)) return null;
  return trimmed;
}
