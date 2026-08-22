import { coachAdapter } from './coach.js';
import { guessAdapter } from './guess.js';
import { michaelKorsAdapter } from './michaelKors.js';
import { steveMaddenAdapter } from './steveMadden.js';
import { marcJacobsAdapter } from './marcJacobs.js';
import { toryBurchAdapter } from './toryBurch.js';
import { kateSpadeAdapter } from './kateSpade.js';
import { guessFactoryAdapter } from './guessFactory.js';
import { gpMcallenAdapter } from './gpMcallen.js';
import type { BrandAdapter } from './types.js';
import type { SourceId } from '../domain/types.js';

export const adapters: Record<SourceId, BrandAdapter> = {
  coach_us: coachAdapter,
  michael_kors_us: michaelKorsAdapter,
  guess_us: guessAdapter,
  steve_madden_us: steveMaddenAdapter,
  marc_jacobs_us: marcJacobsAdapter,
  tory_burch_us: toryBurchAdapter,
  kate_spade_us: kateSpadeAdapter,
  guess_factory_us: guessFactoryAdapter,
  gp_mcallen_perfumes: gpMcallenAdapter,
};

export function adapterFor(sourceId: SourceId): BrandAdapter {
  return adapters[sourceId];
}

export function allAdapters(): BrandAdapter[] {
  return Object.values(adapters);
}
