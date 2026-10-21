// Builds the prototype and serves dist/ with `vite preview` for the checks.
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const viteBin = fileURLToPath(new URL('../node_modules/vite/bin/vite.js', import.meta.url));

function run(args, label) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [viteBin, ...args], { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', (chunk) => (output += chunk));
    child.stderr.on('data', (chunk) => (output += chunk));
    child.on('exit', (code) => (code === 0 ? resolve(output) : reject(new Error(`${label} failed (${code}):\n${output}`))));
  });
}

export async function build() {
  return run(['build'], 'vite build');
}

export async function startPreview(port = 4173) {
  const child = spawn(process.execPath, [viteBin, 'preview', '--port', String(port), '--strictPort', '--host', '127.0.0.1'], {
    cwd: root,
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let output = '';
  child.stdout.on('data', (chunk) => (output += chunk));
  child.stderr.on('data', (chunk) => (output += chunk));
  const url = `http://127.0.0.1:${port}`;
  const started = Date.now();
  while (Date.now() - started < 20000) {
    try {
      const response = await fetch(url);
      if (response.ok) return { url, stop: () => child.kill('SIGTERM'), output: () => output };
    } catch {
      // Not listening yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  child.kill('SIGTERM');
  throw new Error(`vite preview did not start on ${url}:\n${output}`);
}
