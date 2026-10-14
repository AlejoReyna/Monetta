import type { OrdersRepository } from '../domain/ports.js';
import { logger } from '../logger.js';
import { openOrderBlockReason } from './openOrderBlock.js';
import type {
  AccountDeletionAuditRepository,
  AccountDeletionExecute,
  AccountDeletionPrecheck,
  AccountDeletionProgress,
  AccountDeletionStateRepository,
  AppDataEraser,
  BlockingOrderRef,
  CustomerDataEraser,
  FreshLoginVerifier,
  ShopifyCustomerErasureClient,
} from './ports.js';
import { redactLogFields, redactText, sanitizeAuditSteps, sanitizeInternalId } from './redact.js';

const locks = new Map<string, Promise<unknown>>();

export interface AccountDeletionServiceDeps {
  readonly orders: OrdersRepository;
  readonly state: AccountDeletionStateRepository;
  readonly audit: AccountDeletionAuditRepository;
  readonly appData: AppDataEraser;
  readonly customerData: CustomerDataEraser;
  readonly shopifyErasure: ShopifyCustomerErasureClient;
  readonly freshLogin: FreshLoginVerifier;
  /** False when Firebase or the Shopify Admin erasure credential is missing. */
  readonly ready: boolean;
  readonly log?: (
    level: 'info' | 'warn' | 'error',
    message: string,
    fields?: Record<string, unknown>,
  ) => void;
  readonly now?: () => Date;
}

export class AccountDeletionService {
  constructor(private readonly deps: AccountDeletionServiceDeps) {}

  async precheck(shopifyCustomerId: string): Promise<AccountDeletionPrecheck> {
    const customerId = requireCustomerId(shopifyCustomerId);
    const existing = await this.deps.state.get(customerId);
    if (existing?.status === 'completed') {
      return { result: 'deleted', shopifyDataErasure: 'requested' };
    }
    const blocking = await this.findBlockingOrder(customerId);
    if (blocking !== null) {
      await this.record(customerId, 'blocked_open_order', {
        blockCheck: 'blocked',
        firebaseAuth: 'not_attempted',
        firestoreProfile: 'not_attempted',
        firestoreWishlist: 'not_attempted',
        firestoreSavedRecommendations: 'not_attempted',
        postgres: 'not_attempted',
        shopifyErasure: 'not_attempted',
      }, null, null);
      return { result: 'blocked_open_order', order: blocking };
    }
    return { result: 'clear' };
  }

  async execute(accessToken: string, idToken: string): Promise<AccountDeletionExecute> {
    const decision = await this.deps.freshLogin.verify(accessToken, idToken);
    if (decision.status === 'unavailable') return { result: 'unavailable' };
    if (decision.status === 'invalid') return { result: 'unauthorized' };
    if (decision.status === 'stale') {
      await this.record(decision.customerId, 'stale_reauthentication', {
        reauthentication: 'failed',
        firebaseAuth: 'not_attempted',
        firestoreProfile: 'not_attempted',
        firestoreWishlist: 'not_attempted',
        firestoreSavedRecommendations: 'not_attempted',
        postgres: 'not_attempted',
        shopifyErasure: 'not_attempted',
      }, null, null);
      return { result: 'stale_reauthentication' };
    }

    const customerId = requireCustomerId(decision.customerId);
    return this.withLock(customerId, () => this.executeFresh(customerId));
  }

  private async executeFresh(customerId: string): Promise<AccountDeletionExecute> {
    const existing = await this.deps.state.get(customerId);
    if (existing?.status === 'completed') {
      await this.record(customerId, 'deleted', completedSteps(existing), existing.appAccountId, existing.firebaseUid);
      return { result: 'deleted', shopifyDataErasure: 'requested' };
    }

    if (!this.deps.ready) {
      await this.record(customerId, 'failed', {
        configuration: 'failed',
        firebaseAuth: 'not_attempted',
        firestoreProfile: 'not_attempted',
        firestoreWishlist: 'not_attempted',
        firestoreSavedRecommendations: 'not_attempted',
        postgres: 'not_attempted',
        shopifyErasure: 'not_attempted',
      }, existing?.appAccountId ?? null, existing?.firebaseUid ?? null);
      return { result: 'unavailable' };
    }

    let progress = existing;
    if (progress === null) {
      const blocking = await this.findBlockingOrder(customerId);
      if (blocking !== null) {
        await this.record(customerId, 'blocked_open_order', {
          blockCheck: 'blocked',
          firebaseAuth: 'not_attempted',
          firestoreProfile: 'not_attempted',
          firestoreWishlist: 'not_attempted',
          firestoreSavedRecommendations: 'not_attempted',
          postgres: 'not_attempted',
          shopifyErasure: 'not_attempted',
        }, null, null);
        return { result: 'blocked_open_order', order: blocking };
      }
      progress = await this.deps.state.claim(customerId);
      if (progress.status === 'completed') {
        return { result: 'deleted', shopifyDataErasure: 'requested' };
      }
    }

    const steps: Record<string, string> = {
      blockCheck: 'skipped',
      firebaseAuth: progress.firebaseAuth === 'done' ? 'skipped' : 'pending',
      firestoreProfile: progress.firestore === 'done' ? 'skipped' : 'pending',
      firestoreWishlist: progress.firestore === 'done' ? 'skipped' : 'pending',
      firestoreSavedRecommendations: progress.firestore === 'done' ? 'skipped' : 'pending',
      postgres: progress.postgres === 'done' ? 'skipped' : 'pending',
      shopifyErasure: progress.shopifyErasure === 'requested' ? 'requested' : 'pending',
    };

    if (progress.firebaseAuth !== 'done' || progress.firestore !== 'done') {
      try {
        const erased = await this.deps.appData.erase(customerId);
        progress = {
          ...progress,
          firebaseAuth: 'done',
          firestore: 'done',
          firebaseUid: erased.firebaseUid ?? progress.firebaseUid,
        };
        steps.firebaseAuth = erased.firebaseAuth;
        steps.firestoreProfile = erased.profile;
        steps.firestoreWishlist = erased.wishlist;
        steps.firestoreSavedRecommendations = erased.savedRecommendations;
        await this.deps.state.save(progress);
      } catch (error) {
        steps.firebaseAuth = 'failed';
        steps.firestoreProfile = 'failed';
        steps.firestoreWishlist = 'failed';
        steps.firestoreSavedRecommendations = 'failed';
        steps.postgres = 'not_attempted';
        steps.shopifyErasure = 'not_attempted';
        await this.fail(customerId, progress, steps, error, 'app_data');
        return { result: 'failed' };
      }
    }

    if (progress.postgres !== 'done') {
      try {
        const erased = await this.deps.customerData.erase(customerId);
        progress = {
          ...progress,
          postgres: 'done',
          appAccountId: erased.appAccountId ?? progress.appAccountId,
        };
        steps.postgres = 'anonymized';
        await this.deps.state.save(progress);
      } catch (error) {
        steps.postgres = 'failed';
        steps.shopifyErasure = 'not_attempted';
        await this.fail(customerId, progress, steps, error, 'postgres');
        return { result: 'failed' };
      }
    }

    if (progress.shopifyErasure !== 'requested') {
      try {
        await this.deps.shopifyErasure.request(customerId);
        progress = { ...progress, shopifyErasure: 'requested', status: 'completed' };
        steps.shopifyErasure = 'requested';
        await this.deps.state.save(progress);
      } catch (error) {
        steps.shopifyErasure = 'failed';
        await this.fail(customerId, progress, steps, error, 'shopify_erasure');
        return { result: 'failed' };
      }
    } else if (progress.status !== 'completed') {
      progress = { ...progress, status: 'completed' };
      await this.deps.state.save(progress);
    }

    await this.record(
      customerId,
      'deleted',
      steps,
      progress.appAccountId,
      progress.firebaseUid,
    );
    return { result: 'deleted', shopifyDataErasure: 'requested' };
  }

  private async findBlockingOrder(customerId: string): Promise<BlockingOrderRef | null> {
    const orders = await this.deps.orders.listForCustomer(customerId);
    for (const order of orders) {
      const reason = openOrderBlockReason(order);
      if (reason === null) continue;
      return {
        id: String(order.id),
        shopifyOrderId: order.shopifyOrderId,
        reason,
      };
    }
    return null;
  }

  private async fail(
    customerId: string,
    progress: AccountDeletionProgress,
    steps: Record<string, string>,
    error: unknown,
    step: string,
  ): Promise<void> {
    const message = error instanceof Error ? error.message : 'deletion_failed';
    this.writeLog('error', 'account deletion step failed', {
      shopifyCustomerId: customerId,
      step,
      detail: redactText(message).slice(0, 200),
    });
    await this.record(customerId, 'failed', steps, progress.appAccountId, progress.firebaseUid);
  }

  private async record(
    shopifyCustomerId: string,
    result: string,
    steps: Record<string, string>,
    appAccountId: string | null,
    firebaseUid: string | null,
  ): Promise<void> {
    const entry = await this.deps.audit.append({
      shopifyCustomerId,
      appAccountId: sanitizeInternalId(appAccountId),
      firebaseUid: sanitizeInternalId(firebaseUid),
      result,
      steps: sanitizeAuditSteps(steps),
      createdAt: (this.deps.now ?? (() => new Date()))().toISOString(),
    });
    this.writeLog('info', 'account deletion attempt', {
      shopifyCustomerId: entry.shopifyCustomerId,
      result: entry.result,
      steps: entry.steps,
      createdAt: entry.createdAt,
    });
  }

  private writeLog(
    level: 'info' | 'warn' | 'error',
    message: string,
    fields: Record<string, unknown>,
  ): void {
    const safe = redactLogFields(fields) ?? {};
    const sink = this.deps.log;
    if (sink !== undefined) {
      sink(level, message, safe);
      return;
    }
    logger[level](message, safe);
  }

  private async withLock<T>(customerId: string, fn: () => Promise<T>): Promise<T> {
    const previous = locks.get(customerId) ?? Promise.resolve();
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const tail = previous.then(() => gate);
    locks.set(customerId, tail);
    await previous;
    try {
      return await fn();
    } finally {
      release();
      if (locks.get(customerId) === tail) locks.delete(customerId);
    }
  }
}

function requireCustomerId(value: string): string {
  const id = sanitizeInternalId(value);
  if (id === null || !/^[0-9]+$/.test(id)) {
    throw new Error('invalid_customer_id');
  }
  return id;
}

function completedSteps(progress: AccountDeletionProgress): Record<string, string> {
  return {
    firebaseAuth: 'skipped',
    firestoreProfile: 'skipped',
    firestoreWishlist: 'skipped',
    firestoreSavedRecommendations: 'skipped',
    postgres: 'skipped',
    shopifyErasure: progress.shopifyErasure === 'requested' ? 'requested' : 'skipped',
  };
}
