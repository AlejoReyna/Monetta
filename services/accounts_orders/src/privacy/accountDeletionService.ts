import type { AppAccountsRepository, OrdersRepository } from '../domain/ports.js';
import { logger } from '../logger.js';
import { maskAccountEmail, normalizeAccountEmail } from './emailMatch.js';
import { openOrderBlockReason, shopifyOrderNumber } from './openOrderBlock.js';
import type {
  AccountDeletionAuditRepository,
  AccountDeletionExecute,
  AccountDeletionPrecheck,
  AccountDeletionProgress,
  AccountDeletionStateRepository,
  AppDataEraser,
  BlockingOrderRef,
  CustomerAccountEmailLookup,
  CustomerDataEraser,
  DeletionCredential,
  FreshLoginVerifier,
  LegacyEmailMatch,
  ShopifyCustomerErasureClient,
  ShopifyCustomerOrderLookup,
  ShopifyListedOrder,
} from './ports.js';
import { OrderCheckUnavailableError, TooManyOrdersError } from './shopifyOrderCheck.js';
import { redactLogFields, redactText, sanitizeAuditSteps, sanitizeInternalId } from './redact.js';

const locks = new Map<string, Promise<unknown>>();

export interface AccountDeletionServiceDeps {
  readonly orders: OrdersRepository;
  readonly state: AccountDeletionStateRepository;
  readonly audit: AccountDeletionAuditRepository;
  readonly appData: AppDataEraser;
  readonly customerData: CustomerDataEraser;
  readonly shopifyErasure: ShopifyCustomerErasureClient;
  /** Customer Account `customer.orders`. Required before a deletion can proceed. */
  readonly shopifyOrders: ShopifyCustomerOrderLookup;
  readonly freshLogin: FreshLoginVerifier;
  /** Legacy session lookup for the post-login email comparison. */
  readonly appAccounts?: AppAccountsRepository;
  readonly customerEmail?: CustomerAccountEmailLookup;
  readonly hashSessionToken?: (token: string) => string;
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

  async precheck(
    shopifyCustomerId: string,
    accessToken: string,
    credential: DeletionCredential = 'customer_account',
  ): Promise<AccountDeletionPrecheck> {
    const customerId = requireCustomerId(shopifyCustomerId);
    const existing = await this.deps.state.get(customerId);
    if (existing?.status === 'completed') {
      return { result: 'deleted', shopifyDataErasure: 'requested' };
    }
    if (credential === 'monetta_session') {
      await this.recordCheck(customerId, 'reauth_required', 'reauth_required');
      return { result: 'reauth_required' };
    }
    const blocking = await this.findBlockingOrder(customerId, accessToken);
    if (blocking === 'unavailable') {
      await this.recordCheck(customerId, 'order_check_unavailable', 'unavailable');
      return { result: 'order_check_unavailable' };
    }
    if (blocking === 'too_many_orders') {
      await this.recordCheck(customerId, 'too_many_orders', 'too_many_orders');
      return { result: 'too_many_orders' };
    }
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

  async matchLegacyEmail(
    shopifyAccessToken: string,
    legacySessionToken: string,
  ): Promise<LegacyEmailMatch> {
    const legacy = legacySessionToken.trim();
    if (legacy === '' || legacy.length > 8192 || /\s/.test(legacy)) {
      return { result: 'unauthorized' };
    }
    const accounts = this.deps.appAccounts;
    const emails = this.deps.customerEmail;
    const hash = this.deps.hashSessionToken;
    if (accounts === undefined || emails === undefined || hash === undefined) {
      return { result: 'unavailable' };
    }
    const account = await accounts.findByTokenHash(hash(legacy));
    if (account === null) return { result: 'unauthorized' };
    let shopifyEmail: string | null;
    try {
      shopifyEmail = await emails.customerEmail(shopifyAccessToken);
    } catch {
      return { result: 'unavailable' };
    }
    if (shopifyEmail === null) return { result: 'unauthorized' };
    const shopifyNormalized = normalizeAccountEmail(shopifyEmail);
    const legacyNormalized = normalizeAccountEmail(account.email);
    if (shopifyNormalized === null || legacyNormalized === null) {
      return { result: 'unavailable' };
    }
    if (shopifyNormalized !== legacyNormalized) {
      return { result: 'email_mismatch', maskedEmail: maskAccountEmail(legacyNormalized) };
    }
    return { result: 'email_match' };
  }

  async execute(
    accessToken: string,
    idToken: string,
    legacySessionToken?: string | null,
  ): Promise<AccountDeletionExecute> {
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
    const legacy = legacySessionToken?.trim() ?? '';
    if (legacy !== '') {
      const match = await this.matchLegacyEmail(accessToken, legacy);
      if (match.result === 'email_mismatch') {
        await this.recordCheck(customerId, 'email_mismatch', 'email_mismatch');
        return match;
      }
      if (match.result === 'unauthorized') return { result: 'unauthorized' };
      if (match.result === 'unavailable') {
        await this.recordCheck(customerId, 'failed', 'unavailable');
        return { result: 'unavailable' };
      }
    }
    return this.withLock(customerId, () => this.executeFresh(customerId, accessToken));
  }

  private async executeFresh(customerId: string, accessToken: string): Promise<AccountDeletionExecute> {
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
      const blocking = await this.findBlockingOrder(customerId, accessToken);
      if (blocking === 'unavailable') {
        await this.recordCheck(customerId, 'order_check_unavailable', 'unavailable');
        return { result: 'order_check_unavailable' };
      }
      if (blocking === 'too_many_orders') {
        await this.recordCheck(customerId, 'too_many_orders', 'too_many_orders');
        return { result: 'too_many_orders' };
      }
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

  private async findBlockingOrder(
    customerId: string,
    accessToken: string,
  ): Promise<BlockingOrderRef | null | 'unavailable' | 'too_many_orders'> {
    let live: readonly ShopifyListedOrder[];
    try {
      live = await this.deps.shopifyOrders.listOrders(accessToken);
    } catch (error) {
      const tooMany = error instanceof TooManyOrdersError;
      this.writeLog('error', 'account deletion order check failed', {
        shopifyCustomerId: customerId,
        step: 'order_check',
        detail: tooMany
          ? 'too_many_orders'
          : error instanceof OrderCheckUnavailableError
            ? error.name
            : 'order_check_unavailable',
      });
      return tooMany ? 'too_many_orders' : 'unavailable';
    }

    const mirrored = await this.deps.orders.listForCustomer(customerId);
    const tagsByNumber = new Map<string, readonly string[]>();
    for (const order of mirrored) {
      if (order.shopifyOrderId !== null) tagsByNumber.set(order.shopifyOrderId, order.tags);
    }

    const seen = new Set<string>();
    for (const order of live) {
      const number = shopifyOrderNumber(order.id);
      if (number !== null) seen.add(number);
      const mirrorTags = number === null ? [] : tagsByNumber.get(number) ?? [];
      const reason = openOrderBlockReason({
        ...order,
        tags: [...order.tags, ...mirrorTags],
      });
      if (reason === null) continue;
      return blockingRef(number ?? order.id, number, reason, order.name);
    }

    for (const order of mirrored) {
      if (order.shopifyOrderId !== null && seen.has(order.shopifyOrderId)) continue;
      const reason = openOrderBlockReason(order);
      if (reason === null) continue;
      return blockingRef(String(order.id), order.shopifyOrderId, reason, null);
    }
    return null;
  }

  private async recordCheck(customerId: string, result: string, blockCheck: string): Promise<void> {
    await this.record(customerId, result, {
      blockCheck,
      firebaseAuth: 'not_attempted',
      firestoreProfile: 'not_attempted',
      firestoreWishlist: 'not_attempted',
      firestoreSavedRecommendations: 'not_attempted',
      postgres: 'not_attempted',
      shopifyErasure: 'not_attempted',
    }, null, null);
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

function blockingRef(
  id: string,
  shopifyOrderId: string | null,
  reason: BlockingOrderRef['reason'],
  name: string | null | undefined,
): BlockingOrderRef {
  const orderName = shopperOrderName(name);
  return {
    id,
    shopifyOrderId,
    reason,
    ...(orderName === null ? {} : { orderName }),
  };
}

function shopperOrderName(name: string | null | undefined): string | null {
  const trimmed = name?.trim() ?? '';
  if (trimmed === '' || trimmed.includes('@') || trimmed.length > 40) return null;
  return trimmed;
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
