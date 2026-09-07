#!/usr/bin/env node
/**
 * Dashboard passphrase CLI.
 *
 *   npm run dashboard:passphrase
 *
 * Reads the passphrase from stdin (pipe it in — never pass it as a shell
 * argument where it lands in history), prints the
 * `scrypt$<salt>$<hash>` verifier to paste into
 * `DASHBOARD_PASSPHRASE_VERIFIER`, and never writes the passphrase itself
 * anywhere.
 *
 *   echo "$PASSPHRASE" | npm run dashboard:passphrase
 */
import { fileURLToPath } from 'node:url';
import { createInterface } from 'node:readline';
import { createPassphraseVerifier } from '../api/auth.js';

async function readPassphrase(): Promise<string> {
  // Piped input (including `echo ... |`) — consume without echoing.
  if (!process.stdin.isTTY) {
    const chunks: Buffer[] = [];
    for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
    return Buffer.concat(chunks).toString('utf8').split('\n')[0]!.trim();
  }
  const rl = createInterface({ input: process.stdin, output: process.stderr });
  try {
    return await new Promise<string>((resolve) => {
      rl.question('Dashboard passphrase (min 16 chars): ', (answer) => resolve(answer.trim()));
    });
  } finally {
    rl.close();
  }
}

async function main(): Promise<void> {
  const fromArg = process.argv[2];
  const passphrase = fromArg !== undefined && !fromArg.startsWith('--') ? fromArg : await readPassphrase();
  if (!passphrase || passphrase.length < 16) {
    console.error('Passphrase must be at least 16 characters.');
    process.exitCode = 1;
    return;
  }
  const verifier = await createPassphraseVerifier(passphrase);
  console.log(verifier);
  console.error('\nPaste the line above into DASHBOARD_PASSPHRASE_VERIFIER. The passphrase itself was not stored.');
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
