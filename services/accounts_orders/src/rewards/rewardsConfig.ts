import type { ProgramPolicy } from './types.js';
import { DEFAULT_PROGRAM } from './types.js';

export interface RewardsEnv {
  readonly rewardsEnabled: boolean;
  readonly redemptionEnabled: boolean;
  readonly reservationTtlMinutes: number;
  readonly quoteTtlMinutes: number;
}

function bool(value: string | undefined, fallback: boolean): boolean {
  if (value === undefined || value === '') return fallback;
  const v = value.trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(v)) return true;
  if (['0', 'false', 'no', 'off'].includes(v)) return false;
  return fallback;
}

function int(value: string | undefined, fallback: number): number {
  if (value === undefined || value === '') return fallback;
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

export function loadRewardsEnv(env: NodeJS.ProcessEnv = process.env): RewardsEnv {
  return {
    // Programa apagado si falta la variable: montar rutas y puentes de
    // webhook emite creditos, asi que cada entorno lo enciende explicitamente.
    rewardsEnabled: bool(env.REWARDS_ENABLED, false),
    // Canje apagado por defecto: solo se enciende tras la prueba del adaptador
    // en el plan Shopify real. Ver docs del paquete F.
    redemptionEnabled: bool(env.REWARDS_REDEMPTION_ENABLED, false),
    reservationTtlMinutes: int(env.REWARDS_RESERVATION_TTL_MINUTES, 30),
    quoteTtlMinutes: int(env.REWARDS_QUOTE_TTL_MINUTES, 10),
  };
}

/** Politica efectiva: programa v1 con el interruptor de entorno aplicado. */
export function effectivePolicy(env: RewardsEnv = loadRewardsEnv()): ProgramPolicy {
  return {
    ...DEFAULT_PROGRAM,
    redemptionEnabled: env.rewardsEnabled && env.redemptionEnabled,
  };
}
