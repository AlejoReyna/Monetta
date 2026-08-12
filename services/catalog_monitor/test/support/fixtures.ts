import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const FIXTURES_DIR = join(__dirname, '..', 'fixtures');

export function readFixture(relativePath: string): string {
  return readFileSync(join(FIXTURES_DIR, relativePath), 'utf8');
}

/** Builds a fixture-backed sitemap/page fetcher from a `{ url: bodyOrFixturePath }` map. No network — throws on any unmapped URL. */
export function fixtureFetcher(map: Record<string, string>): (url: string) => Promise<string> {
  return async (url: string) => {
    const body = map[url];
    if (body === undefined) throw new Error(`No fixture registered for ${url}`);
    return body;
  };
}
