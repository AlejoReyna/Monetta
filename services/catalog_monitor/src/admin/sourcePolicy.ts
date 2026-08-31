import type { SourceId } from '../domain/types.js';

export interface SourcePolicy {
  readonly sourceId: SourceId;
  readonly enabled: boolean;
  readonly itemLimit: number;
  readonly baseCommissionBps: number;
  readonly highValueCommissionBps: number;
  readonly highValueThresholdMxn: number;
  readonly updatedAt: Date;
}

export interface SourcePolicyRepository {
  list(): Promise<SourcePolicy[]>;
  find(sourceId: SourceId): Promise<SourcePolicy | null>;
  upsert(input: {
    readonly sourceId: SourceId;
    readonly enabled: boolean;
    readonly itemLimit: number;
    readonly baseCommissionBps: number;
    readonly highValueCommissionBps: number;
    readonly highValueThresholdMxn: number;
  }): Promise<SourcePolicy>;
}

export function validateSourcePolicy(input: {
  readonly enabled: unknown;
  readonly itemLimit: unknown;
  readonly baseCommissionBps: unknown;
  readonly highValueCommissionBps: unknown;
  readonly highValueThresholdMxn: unknown;
}): string | null {
  if (typeof input.enabled !== 'boolean') return 'enabled must be boolean';
  if (!Number.isInteger(input.itemLimit) || (input.itemLimit as number) < 0 || (input.itemLimit as number) > 50) {
    return 'itemLimit must be an integer between 0 and 50';
  }
  for (const value of [input.baseCommissionBps, input.highValueCommissionBps]) {
    if (!Number.isInteger(value) || (value as number) < 0 || (value as number) > 10_000) {
      return 'commission rates must be integer basis points between 0 and 10000';
    }
  }
  if (typeof input.highValueThresholdMxn !== 'number' ||
      !Number.isFinite(input.highValueThresholdMxn) ||
      input.highValueThresholdMxn <= 0 ||
      input.highValueThresholdMxn > 1_000_000) {
    return 'highValueThresholdMxn must be a positive number up to 1000000';
  }
  return null;
}
