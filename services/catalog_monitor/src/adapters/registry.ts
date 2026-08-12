import { coachAdapter } from './coach.js';
import { guessAdapter } from './guess.js';
import { michaelKorsAdapter } from './michaelKors.js';
import { steveMaddenAdapter } from './steveMadden.js';
import type { BrandAdapter } from './types.js';
import type { SourceId } from '../domain/types.js';

export const adapters: Record<SourceId, BrandAdapter> = {
  coach_us: coachAdapter,
  michael_kors_us: michaelKorsAdapter,
  guess_us: guessAdapter,
  steve_madden_us: steveMaddenAdapter,
};

export function adapterFor(sourceId: SourceId): BrandAdapter {
  return adapters[sourceId];
}

export function allAdapters(): BrandAdapter[] {
  return Object.values(adapters);
}
