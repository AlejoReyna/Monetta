import { randomBytes } from 'node:crypto';

/**
 * Generate a unique audit_run_id (lowercase hex, time-prefixed for sortability).
 * Resource prefix: monetta-qa-<run-id>
 */
export function generateAuditRunId(now = new Date()) {
  const stamp = now.toISOString().replace(/[-:TZ.]/g, '').slice(0, 14); // YYYYMMDDHHmmss
  const entropy = randomBytes(4).toString('hex');
  return `${stamp}-${entropy}`;
}

export function resourcePrefix(runId) {
  if (!runId || typeof runId !== 'string') {
    throw new Error('audit_run_id is required');
  }
  return `monetta-qa-${runId}`;
}

export function assertValidRunId(runId) {
  if (!/^[0-9]{14}-[a-f0-9]{8}$/.test(runId)) {
    throw new Error(
      `Invalid audit_run_id "${runId}". Expected YYYYMMDDHHmmss-<8hex> from \`audit init\`.`,
    );
  }
}
