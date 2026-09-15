import { open, unlink } from 'node:fs/promises';
import { ensureRunDir } from './manifest.mjs';
import { assertValidRunId } from './runId.mjs';
/** Fail closed on simultaneous/crashed writers. Operator may remove a stale
 * lock only after confirming the recorded process is dead. */
export async function withRunLock(runId, operation) {
  assertValidRunId(runId);
  const path = `${await ensureRunDir(runId)}/writer.lock`;
  let handle;
  try { handle = await open(path, 'wx', 0o600); }
  catch { throw new Error('Run writer lock exists; confirm its process is stopped before recovery'); }
  try {
    await handle.writeFile(`${process.pid}\n`);
    return await operation();
  } finally {
    await handle.close(); await unlink(path);
  }
}
