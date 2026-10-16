import { createSign, generateKeyPairSync, type JsonWebKey } from 'node:crypto';
import type { Server } from 'node:http';
import { afterEach, describe, expect, it } from 'vitest';
import { hashAdminBearerToken } from '../src/admin/authorizer.js';
import { createApp, type ServerDeps } from '../src/api/server.js';
import type { CustomerTokenVerifier } from '../src/auth/customerTokenVerifier.js';
import type { OrdersRepository } from '../src/domain/ports.js';
import type { OrderRecord } from '../src/domain/types.js';
import { AccountDeletionService } from '../src/privacy/accountDeletionService.js';
import { ShopifyFreshLoginVerifier } from '../src/privacy/freshLogin.js';
import { FirebaseAppDataEraser } from '../src/privacy/firebaseAppData.js';
import { maskAccountEmail, normalizeAccountEmail } from '../src/privacy/emailMatch.js';
import { openOrderBlockReason } from '../src/privacy/openOrderBlock.js';
import type {
  AccountDeletionAuditEntry,
  AccountDeletionAuditRepository,
  AccountDeletionProgress,
  AccountDeletionStateRepository,
  AppDataEraser,
  AppDataErasureResult,
  CustomerAccountEmailLookup,
  CustomerDataEraser,
  FreshLoginVerifier,
  ShopifyCustomerErasureClient,
  ShopifyCustomerOrderLookup,
  ShopifyListedOrder,
} from '../src/privacy/ports.js';
import { CustomerAccountOrderLookup, OrderCheckUnavailableError, TooManyOrdersError } from '../src/privacy/shopifyOrderCheck.js';
import { redactLogFields, redactText, sanitizeAuditSteps } from '../src/privacy/redact.js';
import { ShopifyCustomerDataErasureClient } from '../src/privacy/shopifyErasure.js';
import {
  InMemoryAppAccountsRepository,
  InMemoryCustomersRepository,
  InMemoryOrdersRepository,
  InMemoryPushTokensRepository,
  InMemoryWebhookEventsRepository,
} from './support/inMemoryRepositories.js';

const secret = 'shpss_test_secret';

class MemoryState implements AccountDeletionStateRepository {
  readonly rows = new Map<string, AccountDeletionProgress>();

  async get(shopifyCustomerId: string): Promise<AccountDeletionProgress | null> {
    return this.rows.get(shopifyCustomerId) ?? null;
  }

  async claim(shopifyCustomerId: string): Promise<AccountDeletionProgress> {
    const existing = this.rows.get(shopifyCustomerId);
    if (existing !== undefined) return existing;
    const created: AccountDeletionProgress = {
      shopifyCustomerId,
      status: 'in_progress',
      firebaseAuth: 'pending',
      firestore: 'pending',
      postgres: 'pending',
      shopifyErasure: 'pending',
      appAccountId: null,
      firebaseUid: null,
    };
    this.rows.set(shopifyCustomerId, created);
    return created;
  }

  async save(progress: AccountDeletionProgress): Promise<void> {
    this.rows.set(progress.shopifyCustomerId, progress);
  }
}

class MemoryAudit implements AccountDeletionAuditRepository {
  readonly entries: AccountDeletionAuditEntry[] = [];

  async append(entry: Omit<AccountDeletionAuditEntry, 'createdAt'> & { createdAt?: string }): Promise<AccountDeletionAuditEntry> {
    const stored: AccountDeletionAuditEntry = {
      shopifyCustomerId: entry.shopifyCustomerId,
      appAccountId: entry.appAccountId,
      firebaseUid: entry.firebaseUid,
      result: entry.result,
      steps: sanitizeAuditSteps({ ...entry.steps }),
      createdAt: entry.createdAt ?? new Date().toISOString(),
    };
    this.entries.push(stored);
    return stored;
  }

  async list(shopifyCustomerId: string): Promise<readonly AccountDeletionAuditEntry[]> {
    return this.entries.filter((entry) => entry.shopifyCustomerId === shopifyCustomerId);
  }
}

class FakeFreshLogin implements FreshLoginVerifier {
  mode: 'fresh' | 'stale' | 'invalid' | 'unavailable' = 'fresh';
  customerId = '77';

  async verify(accessToken: string, idToken: string) {
    if (accessToken === '' || idToken === '') return { status: 'invalid' as const };
    if (this.mode === 'fresh') {
      return {
        status: 'fresh' as const,
        customerId: this.customerId,
        authenticatedAt: new Date().toISOString(),
      };
    }
    if (this.mode === 'stale') return { status: 'stale' as const, customerId: this.customerId };
    if (this.mode === 'unavailable') return { status: 'unavailable' as const };
    return { status: 'invalid' as const };
  }
}

class FakeAppData implements AppDataEraser {
  calls = 0;
  fail = false;
  result: AppDataErasureResult = {
    firebaseAuth: 'deleted',
    profile: 'deleted',
    wishlist: 'absent',
    savedRecommendations: 'deleted',
    firebaseUid: 'uid-77',
  };

  readonly customerIds: string[] = [];

  async erase(customerId: string): Promise<AppDataErasureResult> {
    this.customerIds.push(customerId);
    this.calls += 1;
    if (this.fail) throw new Error('firebase down for ana@example.com card 4242424242424242');
    return this.result;
  }
}

class FakeCustomerData implements CustomerDataEraser {
  calls = 0;
  fail = false;

  readonly customerIds: string[] = [];

  async erase(customerId: string): Promise<{ appAccountId: string | null }> {
    this.customerIds.push(customerId);
    this.calls += 1;
    if (this.fail) throw new Error('postgres down ana@example.com');
    return { appAccountId: '11111111-1111-1111-1111-111111111111' };
  }
}

class FakeCustomerEmail implements CustomerAccountEmailLookup {
  email: string | null = null;
  fail = false;

  async customerEmail(): Promise<string | null> {
    if (this.fail) throw new OrderCheckUnavailableError();
    return this.email;
  }
}

class FakeOrderLookup implements ShopifyCustomerOrderLookup {
  orders: ShopifyListedOrder[] = [];
  fail = false;
  tooMany = false;
  calls = 0;
  token: string | null = null;

  async listOrders(accessToken: string): Promise<readonly ShopifyListedOrder[]> {
    this.calls += 1;
    this.token = accessToken;
    if (this.tooMany) throw new TooManyOrdersError();
    if (this.fail || accessToken.trim() === '') throw new OrderCheckUnavailableError();
    return this.orders;
  }
}

class FakeShopify implements ShopifyCustomerErasureClient {
  calls = 0;
  fail = false;

  readonly customerIds: string[] = [];

  async request(customerId: string): Promise<'requested'> {
    this.customerIds.push(customerId);
    this.calls += 1;
    if (this.fail) throw new Error('shopify rejected ana@example.com');
    return 'requested';
  }
}

function order(partial: Partial<OrderRecord> & Pick<OrderRecord, 'financialStatus' | 'fulfillmentStatus'>): OrderRecord {
  return {
    shopifyOrderId: '1001',
    customerId: '77',
    source: 'shopify_checkout',
    attributionCode: null,
    tags: [],
    totalAmount: 1999,
    currencyCode: 'MXN',
    attributionDeviceId: 'device-secret',
    attributionRecoSource: null,
    placedAt: new Date('2026-01-01T00:00:00Z'),
    ...partial,
  };
}

function harness(options?: {
  readonly ready?: boolean;
  readonly appAccounts?: InMemoryAppAccountsRepository;
  readonly customerEmail?: CustomerAccountEmailLookup;
}) {
  const orders = new InMemoryOrdersRepository();
  const state = new MemoryState();
  const audit = new MemoryAudit();
  const fresh = new FakeFreshLogin();
  const appData = new FakeAppData();
  const customerData = new FakeCustomerData();
  const shopify = new FakeShopify();
  const shopifyOrders = new FakeOrderLookup();
  const logs: Array<{ level: string; message: string; fields?: Record<string, unknown> }> = [];
  const service = new AccountDeletionService({
    orders,
    state,
    audit,
    appData,
    customerData,
    shopifyErasure: shopify,
    shopifyOrders,
    freshLogin: fresh,
    appAccounts: options?.appAccounts,
    customerEmail: options?.customerEmail,
    hashSessionToken: hashAdminBearerToken,
    ready: options?.ready ?? true,
    log: (level, message, fields) => logs.push({ level, message, fields }),
    now: () => new Date('2026-10-14T08:00:00.000Z'),
  });
  return { orders, state, audit, fresh, appData, customerData, shopify, shopifyOrders, logs, service };
}

describe('open order block check', () => {
  it('blocks unpaid, unfulfilled, and in-progress refunds', () => {
    expect(openOrderBlockReason({
      financialStatus: 'pending',
      fulfillmentStatus: 'fulfilled',
      tags: [],
    })).toBe('unpaid_or_pending');
    expect(openOrderBlockReason({
      financialStatus: 'paid',
      fulfillmentStatus: null,
      tags: [],
    })).toBe('unfulfilled');
    expect(openOrderBlockReason({
      financialStatus: 'partially_paid',
      fulfillmentStatus: 'partial',
      tags: [],
    })).toBe('unpaid_or_pending');
    expect(openOrderBlockReason({
      financialStatus: 'paid',
      fulfillmentStatus: 'fulfilled',
      tags: ['refund-in-progress'],
    })).toBe('refund_in_progress');
    expect(openOrderBlockReason({
      financialStatus: 'refunding',
      fulfillmentStatus: 'fulfilled',
      tags: [],
    })).toBe('refund_in_progress');
    expect(openOrderBlockReason({
      financialStatus: 'pending_refund',
      fulfillmentStatus: 'fulfilled',
      tags: [],
    })).toBe('refund_in_progress');
    expect(openOrderBlockReason({
      financialStatus: 'refund_pending',
      fulfillmentStatus: 'fulfilled',
      tags: [],
    })).toBe('refund_in_progress');
    expect(openOrderBlockReason({
      financialStatus: 'refund_in_progress',
      fulfillmentStatus: 'fulfilled',
      tags: [],
    })).toBe('refund_in_progress');
  });

  it('allows paid fulfilled orders and closed voids or refunds', () => {
    expect(openOrderBlockReason({
      financialStatus: 'paid',
      fulfillmentStatus: 'fulfilled',
      tags: [],
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'PAID',
      fulfillmentStatus: 'Delivered',
      tags: [],
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'voided',
      fulfillmentStatus: null,
      tags: ['refund-in-progress'],
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'refunded',
      fulfillmentStatus: 'unfulfilled',
      tags: [],
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      tags: ['cancelled'],
    })).toBe('payment_review');
    expect(openOrderBlockReason({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      tags: [],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBe('payment_review');
    expect(openOrderBlockReason({
      financialStatus: 'partially_paid',
      fulfillmentStatus: 'fulfilled',
      tags: [],
      cancelReason: 'customer',
    })).toBe('payment_review');
    expect(openOrderBlockReason({
      financialStatus: 'partially_refunded',
      fulfillmentStatus: 'unfulfilled',
      tags: [],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBe('refund_review');
    expect(openOrderBlockReason({
      financialStatus: 'partially_refunded',
      fulfillmentStatus: 'unfulfilled',
      tags: ['Monetta-Reembolso-Revisado'],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'partially_refunded',
      fulfillmentStatus: 'unfulfilled',
      tags: [' monetta-reembolso-revisado '],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'partially_refunded',
      fulfillmentStatus: 'unfulfilled',
      tags: ['monetta-reembolso-revisado-extra'],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBe('refund_review');
    expect(openOrderBlockReason({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      tags: ['monetta-reembolso-revisado'],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBe('payment_review');
    expect(openOrderBlockReason({
      financialStatus: 'partially_paid',
      fulfillmentStatus: 'unfulfilled',
      tags: [' Monetta-Reembolso-Revisado '],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBe('payment_review');
    expect(openOrderBlockReason({
      financialStatus: 'refund_in_progress',
      fulfillmentStatus: 'fulfilled',
      tags: ['monetta-reembolso-revisado'],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBe('refund_in_progress');
    expect(openOrderBlockReason({
      financialStatus: 'pending',
      fulfillmentStatus: null,
      tags: [],
      cancelReason: 'customer',
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'cancelled',
      fulfillmentStatus: 'unfulfilled',
      tags: [],
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'canceled',
      fulfillmentStatus: 'unfulfilled',
      tags: [],
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      tags: ['refund-in-progress'],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBe('refund_in_progress');
    expect(openOrderBlockReason({
      financialStatus: 'refunded',
      fulfillmentStatus: 'unfulfilled',
      tags: [],
      cancelledAt: '2026-02-01T00:00:00Z',
    })).toBeNull();
    expect(openOrderBlockReason({
      financialStatus: 'partially_refunded',
      fulfillmentStatus: 'fulfilled',
      tags: [],
    })).toBeNull();
  });
});

describe('account deletion', () => {
  it('returns blocked_open_order and deletes nothing', async () => {
    const { orders, service, appData, customerData, shopify, audit, state } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'pending',
      fulfillmentStatus: 'unfulfilled',
      shopifyOrderId: '555',
    }));

    const precheck = await service.precheck('77', 'access');
    expect(precheck).toEqual({
      result: 'blocked_open_order',
      order: { id: '1', shopifyOrderId: '555', reason: 'unpaid_or_pending' },
    });
    const executed = await service.execute('access', 'id-token');
    expect(executed.result).toBe('blocked_open_order');
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
    expect(audit.entries.every((entry) => entry.result === 'blocked_open_order')).toBe(true);
    expect(JSON.stringify(audit.entries)).not.toContain('1999');
    expect(JSON.stringify(audit.entries)).not.toContain('device-secret');
  });

  it('is idempotent and does not report a partial failure as success', async () => {
    const { orders, service, appData, customerData, shopify, audit } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'paid',
      fulfillmentStatus: 'fulfilled',
    }));
    customerData.fail = true;

    const first = await service.execute('access', 'id-token');
    expect(first).toEqual({ result: 'failed' });
    expect(appData.calls).toBe(1);
    expect(customerData.calls).toBe(1);
    expect(shopify.calls).toBe(0);
    expect(audit.entries.at(-1)?.result).toBe('failed');

    customerData.fail = false;
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'pending',
      fulfillmentStatus: 'unfulfilled',
      shopifyOrderId: '1001',
    }));
    const second = await service.execute('access', 'id-token');
    expect(second).toEqual({ result: 'deleted', shopifyDataErasure: 'requested' });
    expect(appData.calls).toBe(1);
    expect(customerData.calls).toBe(2);
    expect(shopify.calls).toBe(1);

    shopify.fail = true;
    const third = await service.execute('access', 'id-token');
    expect(third).toEqual({ result: 'deleted', shopifyDataErasure: 'requested' });
    expect(shopify.calls).toBe(1);
    expect(appData.calls).toBe(1);
    expect(audit.entries.some((entry) => entry.result === 'deleted')).toBe(true);
  });

  it('retries Shopify erasure without reporting the first failure as success', async () => {
    const { service, shopify, audit } = harness();
    shopify.fail = true;
    expect(await service.execute('access', 'id-token')).toEqual({ result: 'failed' });
    expect(audit.entries.at(-1)?.steps.shopifyErasure).toBe('failed');
    shopify.fail = false;
    expect(await service.execute('access', 'id-token')).toEqual({
      result: 'deleted',
      shopifyDataErasure: 'requested',
    });
    expect(shopify.calls).toBe(2);
  });

  it('rejects a stale reauthentication before deleting', async () => {
    const { service, fresh, appData, customerData, shopify, audit } = harness();
    fresh.mode = 'stale';
    expect(await service.execute('access', 'id-token')).toEqual({ result: 'stale_reauthentication' });
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(audit.entries[0]?.result).toBe('stale_reauthentication');
  });

  it('does not start deletion when erasure dependencies are not configured', async () => {
    const { service, appData, customerData, shopify, state } = harness({ ready: false });
    expect(await service.execute('access', 'id-token')).toEqual({ result: 'unavailable' });
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
  });

  it('redacts email, address, and payment data from logs and the audit', async () => {
    expect(redactText('fail ana@example.com card 4242424242424242')).toBe('fail [redacted] card [redacted]');
    expect(redactLogFields({
      email: 'ana@example.com',
      shippingAddress: 'Calle 1',
      paymentMethod: 'visa',
      shopifyCustomerId: '77',
      nested: { cardNumber: '4111111111111111', note: 'write ana@example.com' },
    })).toEqual({
      shopifyCustomerId: '77',
      nested: { note: 'write [redacted]' },
    });
    expect(sanitizeAuditSteps({
      email: 'ana@example.com',
      postgres: 'anonymized',
      shopifyErasure: 'please email ana@example.com',
    })).toEqual({
      postgres: 'anonymized',
      shopifyErasure: 'failed',
    });

    const { service, appData, audit, logs } = harness();
    appData.fail = true;
    expect(await service.execute('access', 'id-token')).toEqual({ result: 'failed' });
    const serialized = JSON.stringify({ audit: audit.entries, logs });
    expect(serialized).not.toContain('ana@example.com');
    expect(serialized).not.toContain('4242');
    expect(serialized).not.toContain('@');
    expect(audit.entries[0]?.shopifyCustomerId).toBe('77');
    expect(audit.entries[0]?.createdAt).toBe('2026-10-14T08:00:00.000Z');
    expect(audit.entries[0]?.steps.firebaseAuth).toBe('failed');
  });

  it('does not block a cancelled unfulfilled order that was never charged', async () => {
    const { orders, service, shopifyOrders, appData, customerData, shopify } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      shopifyOrderId: '900',
      tags: [],
    }));
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/900',
      financialStatus: 'PENDING',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: '2026-03-01T12:00:00Z',
      cancelReason: 'customer',
      tags: [],
    }];

    const precheck = await service.precheck('77', 'shopify-token-77');
    expect(precheck).toEqual({ result: 'clear' });
    const executed = await service.execute('access', 'id-token');
    expect(executed).toEqual({ result: 'deleted', shopifyDataErasure: 'requested' });
    expect(appData.calls).toBe(1);
    expect(customerData.calls).toBe(1);
    expect(shopify.calls).toBe(1);
  });

  it('asks for a payment review on a cancelled charge with no refund', async () => {
    const { service, shopifyOrders, appData, customerData, shopify, state } = harness();
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/900',
      name: '#1042',
      financialStatus: 'PAID',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: '2026-03-01T12:00:00Z',
      cancelReason: 'customer',
      tags: [],
    }];

    const precheck = await service.precheck('77', 'shopify-token-77');
    expect(precheck).toEqual({
      result: 'blocked_open_order',
      order: {
        id: '900',
        shopifyOrderId: '900',
        reason: 'payment_review',
        orderName: '#1042',
      },
    });
    const executed = await service.execute('access', 'id-token');
    expect(executed.result).toBe('blocked_open_order');
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
  });

  it('asks for a refund review on a cancelled partial refund until the tag is set', async () => {
    const { orders, service, shopifyOrders, appData, customerData, shopify, state } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'partially_refunded',
      fulfillmentStatus: 'unfulfilled',
      shopifyOrderId: '900',
      tags: [],
    }));
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/900',
      name: '#1042',
      financialStatus: 'PARTIALLY_REFUNDED',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: '2026-03-01T12:00:00Z',
      cancelReason: 'customer',
      tags: [],
    }];

    const precheck = await service.precheck('77', 'shopify-token-77');
    expect(precheck).toEqual({
      result: 'blocked_open_order',
      order: {
        id: '900',
        shopifyOrderId: '900',
        reason: 'refund_review',
        orderName: '#1042',
      },
    });
    expect((await service.execute('access', 'id-token')).result).toBe('blocked_open_order');
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
  });

  it('releases a cancelled partial refund when the mirror has the review tag', async () => {
    const { orders, service, shopifyOrders, appData } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      shopifyOrderId: '900',
      tags: ['Monetta-Reembolso-Revisado'],
    }));
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/900',
      name: '#1042',
      financialStatus: 'PARTIALLY_REFUNDED',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: '2026-03-01T12:00:00Z',
      cancelReason: null,
      tags: [],
    }];

    expect(await service.precheck('77', 'shopify-token-77')).toEqual({ result: 'clear' });
    expect(await service.execute('access', 'id-token')).toEqual({
      result: 'deleted',
      shopifyDataErasure: 'requested',
    });
    expect(appData.calls).toBe(1);
  });

  it('keeps a cancelled paid order in payment review when the refund tag is present', async () => {
    const { orders, service, shopifyOrders, appData, customerData, shopify } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      shopifyOrderId: '900',
      tags: ['monetta-reembolso-revisado'],
    }));
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/900',
      name: '#1042',
      financialStatus: 'PAID',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: '2026-03-01T12:00:00Z',
      cancelReason: null,
      tags: [],
    }];

    const precheck = await service.precheck('77', 'shopify-token-77');
    expect(precheck).toEqual({
      result: 'blocked_open_order',
      order: {
        id: '900',
        shopifyOrderId: '900',
        reason: 'payment_review',
        orderName: '#1042',
      },
    });
    expect((await service.execute('access', 'id-token')).result).toBe('blocked_open_order');
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
  });

  it('keeps a real refund in progress blocked when the review tag is present', async () => {
    const { orders, service, shopifyOrders, appData } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'partially_refunded',
      fulfillmentStatus: 'fulfilled',
      shopifyOrderId: '900',
      tags: ['monetta-reembolso-revisado', 'refund-in-progress'],
    }));
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/900',
      name: '#1042',
      financialStatus: 'PARTIALLY_REFUNDED',
      fulfillmentStatus: 'FULFILLED',
      cancelledAt: '2026-03-01T12:00:00Z',
      cancelReason: null,
      tags: [],
    }];

    const precheck = await service.precheck('77', 'shopify-token-77');
    expect(precheck).toEqual({
      result: 'blocked_open_order',
      order: {
        id: '900',
        shopifyOrderId: '900',
        reason: 'refund_in_progress',
        orderName: '#1042',
      },
    });
    expect(appData.calls).toBe(0);
  });

  it('asks a legacy Monetta session to sign in again and deletes nothing', async () => {
    const { service, shopifyOrders, appData, audit } = harness();
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/1',
      financialStatus: 'PENDING',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: null,
      cancelReason: null,
      tags: [],
    }];

    const precheck = await service.precheck('77', 'legacy-session', 'monetta_session');
    expect(precheck).toEqual({ result: 'reauth_required' });
    expect(shopifyOrders.calls).toBe(0);
    expect(appData.calls).toBe(0);
    expect(JSON.stringify(audit.entries)).not.toContain('legacy-session');
    expect(JSON.stringify(audit.entries)).not.toContain('@');
  });

  it('returns too_many_orders and deletes nothing', async () => {
    const { service, shopifyOrders, appData, customerData, shopify, state } = harness();
    shopifyOrders.tooMany = true;

    expect(await service.precheck('77', 'shopify-token-77')).toEqual({ result: 'too_many_orders' });
    expect(await service.execute('access', 'id-token')).toEqual({ result: 'too_many_orders' });
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
  });

  it('blocks an open order that never reached the mirror', async () => {
    const { service, shopifyOrders, appData, customerData, shopify, state } = harness();
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/42',
      financialStatus: 'PENDING',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: null,
      cancelReason: null,
      tags: [],
    }];

    const precheck = await service.precheck('77', 'shopify-token-77');
    expect(precheck).toEqual({
      result: 'blocked_open_order',
      order: { id: '42', shopifyOrderId: '42', reason: 'unpaid_or_pending' },
    });
    const executed = await service.execute('access', 'id-token');
    expect(executed.result).toBe('blocked_open_order');
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
  });

  it('fails closed when the Shopify order check cannot complete', async () => {
    const { service, shopifyOrders, appData, customerData, shopify, audit, state } = harness();
    shopifyOrders.fail = true;

    const precheck = await service.precheck('77', 'shopify-token-77');
    expect(precheck).toEqual({ result: 'order_check_unavailable' });
    const executed = await service.execute('access', 'id-token');
    expect(executed).toEqual({ result: 'order_check_unavailable' });
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
    const serialized = JSON.stringify(audit.entries);
    expect(serialized).toContain('order_check_unavailable');
    expect(serialized).not.toContain('@');
    expect(serialized).not.toContain('shopify-token');
  });
});

describe('legacy email match', () => {
  it('masks the legacy address as the first character plus the domain', () => {
    expect(normalizeAccountEmail('  Alexis@Gmail.com ')).toBe('alexis@gmail.com');
    expect(maskAccountEmail('  Alexis@Gmail.com ')).toBe('a•••@gmail.com');
    expect(maskAccountEmail('a@gmail.com')).toBe('a•••@gmail.com');
  });

  async function legacyAccounts(email: string, token = 'legacy-session-token') {
    const accounts = new InMemoryAppAccountsRepository();
    await accounts.register({
      accountId: '11111111-1111-4111-8111-111111111111',
      email,
      displayName: null,
      passwordHash: 'scrypt$salt$hash',
      deviceId: 'device-1',
      tokenHash: hashAdminBearerToken(token),
      expiresAt: new Date('2027-01-01T00:00:00Z'),
    });
    const account = accounts.byId.get('11111111-1111-4111-8111-111111111111');
    if (account === undefined) throw new Error('missing account');
    accounts.byId.set(account.id, { ...account, shopifyCustomerId: '77' });
    return accounts;
  }

  it('deletes nothing when the Shopify email does not match', async () => {
    const token = 'legacy-session-token';
    const accounts = await legacyAccounts('Alexis@Gmail.com', token);
    const customerEmail = new FakeCustomerEmail();
    customerEmail.email = 'other@gmail.com';
    const { service, appData, customerData, shopify, audit, state } = harness({
      appAccounts: accounts,
      customerEmail,
    });

    expect(await service.matchLegacyEmail('shopify-token-77', token)).toEqual({
      result: 'email_mismatch',
      maskedEmail: 'a•••@gmail.com',
    });
    expect(await service.execute('access', 'id-token', token)).toEqual({
      result: 'email_mismatch',
      maskedEmail: 'a•••@gmail.com',
    });
    expect(appData.calls).toBe(0);
    expect(customerData.calls).toBe(0);
    expect(shopify.calls).toBe(0);
    expect(state.rows.size).toBe(0);
    const serialized = JSON.stringify(audit.entries);
    expect(serialized).toContain('email_mismatch');
    expect(serialized).not.toContain('@');
    expect(serialized).not.toContain('Alexis');
    expect(serialized).not.toContain('gmail');
  });

  it('deletes when the emails match after trim and lowercase', async () => {
    const token = 'legacy-session-token';
    const accounts = await legacyAccounts('  Alexis@Gmail.com ', token);
    const customerEmail = new FakeCustomerEmail();
    customerEmail.email = 'alexis@gmail.com';
    const { service, appData, shopify } = harness({ appAccounts: accounts, customerEmail });

    expect(await service.matchLegacyEmail('shopify-token-77', token)).toEqual({
      result: 'email_match',
    });
    expect(await service.execute('access', 'id-token', token)).toEqual({
      result: 'deleted',
      shopifyDataErasure: 'requested',
    });
    expect(appData.calls).toBe(1);
    expect(shopify.calls).toBe(1);
  });
});

describe('account deletion HTTP', () => {
  let server: Server;
  let baseUrl: string;

  afterEach(async () => {
    if (server === undefined) return;
    await new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  });

  async function start(
    orders: OrdersRepository,
    service: AccountDeletionService,
    appAccounts = new InMemoryAppAccountsRepository(),
  ): Promise<void> {
    const customerTokenVerifier: CustomerTokenVerifier = {
      async resolveCustomerId(accessToken: string) {
        return accessToken === 'shopify-token-77' ? 'gid://shopify/Customer/77' : null;
      },
    };
    const deps: ServerDeps = {
      appAccounts,
      customers: new InMemoryCustomersRepository(),
      orders,
      webhookEvents: new InMemoryWebhookEventsRepository(),
      pushTokens: new InMemoryPushTokensRepository(),
      webhookSecret: secret,
      customerTokenVerifier,
      accountDeletion: service,
    };
    const app = createApp(deps);
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
  }

  it('DEL-14: ignores client customer IDs and erases only the token customer', async () => {
    const { service, appData, customerData, shopify, state, audit } = harness();
    await start(new InMemoryOrdersRepository(), service);

    const response = await fetch(`${baseUrl}/customers/me/account-deletion?customerId=88`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Id-Token': 'fresh-id-token',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ customerId: '88', shopifyCustomerId: 'gid://shopify/Customer/88' }),
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ result: 'deleted', shopifyDataErasure: 'requested' });
    expect(appData.customerIds).toEqual(['77']);
    expect(customerData.customerIds).toEqual(['77']);
    expect(shopify.customerIds).toEqual(['77']);
    expect(await state.get('88')).toBeNull();
    expect(await audit.list('88')).toEqual([]);
  });

  it('precheck blocks and the response carries no payment or contact data', async () => {
    const { orders, service } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'authorized',
      fulfillmentStatus: null,
      shopifyOrderId: '900',
      tags: ['ana@example.com'],
    }));
    await start(orders, service);

    const missing = await fetch(`${baseUrl}/customers/me/account-deletion/precheck`, { method: 'POST' });
    expect(missing.status).toBe(401);

    const blocked = await fetch(`${baseUrl}/customers/me/account-deletion/precheck`, {
      method: 'POST',
      headers: { Authorization: 'Bearer shopify-token-77' },
    });
    expect(blocked.status).toBe(200);
    const body = await blocked.json() as { result: string; order: { id: string; shopifyOrderId: string } };
    expect(body).toEqual({
      result: 'blocked_open_order',
      order: { id: '1', shopifyOrderId: '900', reason: 'unpaid_or_pending' },
    });
    expect(JSON.stringify(body)).not.toContain('@');
    expect(JSON.stringify(body)).not.toContain('1999');
    expect(JSON.stringify(body)).not.toContain('MXN');
  });

  it('returns order_check_unavailable and deletes nothing when Shopify cannot be read', async () => {
    const { service, shopifyOrders, shopify } = harness();
    shopifyOrders.fail = true;
    await start(new InMemoryOrdersRepository(), service);

    const response = await fetch(`${baseUrl}/customers/me/account-deletion/precheck`, {
      method: 'POST',
      headers: { Authorization: 'Bearer shopify-token-77' },
    });
    expect(response.status).toBe(503);
    expect(await response.json()).toEqual({ error: 'order_check_unavailable' });

    const deleted = await fetch(`${baseUrl}/customers/me/account-deletion`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Id-Token': 'fresh-id-token',
      },
    });
    expect(deleted.status).toBe(503);
    expect(await deleted.json()).toEqual({ error: 'order_check_unavailable' });
    expect(shopify.calls).toBe(0);
  });

  it('returns reauth_required for a legacy Monetta session', async () => {
    const { service, shopifyOrders } = harness();
    const accounts = new InMemoryAppAccountsRepository();
    const token = 'legacy-session-token';
    await accounts.register({
      accountId: '11111111-1111-4111-8111-111111111111',
      email: 'legacy@example.com',
      displayName: null,
      passwordHash: 'scrypt$salt$hash',
      deviceId: 'device-1',
      tokenHash: hashAdminBearerToken(token),
      expiresAt: new Date('2027-01-01T00:00:00Z'),
    });
    const account = accounts.byId.get('11111111-1111-4111-8111-111111111111');
    if (account === undefined) throw new Error('missing account');
    accounts.byId.set(account.id, { ...account, shopifyCustomerId: '77' });
    await start(new InMemoryOrdersRepository(), service, accounts);

    const response = await fetch(`${baseUrl}/customers/me/account-deletion/precheck`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body).toEqual({ result: 'reauth_required' });
    expect(shopifyOrders.calls).toBe(0);
    expect(JSON.stringify(body)).not.toContain('@');
  });

  it('returns email_mismatch and deletes nothing', async () => {
    const token = 'legacy-session-token';
    const accounts = new InMemoryAppAccountsRepository();
    await accounts.register({
      accountId: '11111111-1111-4111-8111-111111111111',
      email: 'Alexis@Gmail.com',
      displayName: null,
      passwordHash: 'scrypt$salt$hash',
      deviceId: 'device-1',
      tokenHash: hashAdminBearerToken(token),
      expiresAt: new Date('2027-01-01T00:00:00Z'),
    });
    const stored = accounts.byId.get('11111111-1111-4111-8111-111111111111');
    if (stored === undefined) throw new Error('missing account');
    accounts.byId.set(stored.id, { ...stored, shopifyCustomerId: '77' });
    const customerEmail = new FakeCustomerEmail();
    customerEmail.email = 'other@gmail.com';
    const { service, shopify, appData } = harness({ appAccounts: accounts, customerEmail });
    await start(new InMemoryOrdersRepository(), service, accounts);

    const matched = await fetch(`${baseUrl}/customers/me/account-deletion/email-match`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Legacy-Session': token,
      },
    });
    expect(matched.status).toBe(200);
    expect(await matched.json()).toEqual({
      result: 'email_mismatch',
      maskedEmail: 'a•••@gmail.com',
    });

    const deleted = await fetch(`${baseUrl}/customers/me/account-deletion`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Id-Token': 'fresh-id-token',
        'X-Monetta-Legacy-Session': token,
      },
    });
    expect(deleted.status).toBe(200);
    const body = await deleted.json();
    expect(body).toEqual({
      result: 'email_mismatch',
      maskedEmail: 'a•••@gmail.com',
    });
    expect(JSON.stringify(body)).not.toContain('Alexis');
    expect(JSON.stringify(body)).not.toContain('alexis@gmail.com');
    expect(shopify.calls).toBe(0);
    expect(appData.calls).toBe(0);
  });

  it('returns too_many_orders without deleting', async () => {
    const { service, shopifyOrders, shopify } = harness();
    shopifyOrders.tooMany = true;
    await start(new InMemoryOrdersRepository(), service);

    const response = await fetch(`${baseUrl}/customers/me/account-deletion/precheck`, {
      method: 'POST',
      headers: { Authorization: 'Bearer shopify-token-77' },
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ result: 'too_many_orders' });
    expect(shopify.calls).toBe(0);
  });

  it('returns payment_review for a cancelled charge and deletes nothing', async () => {
    const { orders, service, shopifyOrders, shopify, appData } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'paid',
      fulfillmentStatus: 'unfulfilled',
      shopifyOrderId: '900',
      tags: ['monetta-reembolso-revisado'],
    }));
    shopifyOrders.orders = [{
      id: 'gid://shopify/Order/900',
      name: '#1042',
      financialStatus: 'PARTIALLY_PAID',
      fulfillmentStatus: 'UNFULFILLED',
      cancelledAt: '2026-03-01T12:00:00Z',
      cancelReason: 'customer',
      tags: [],
    }];
    await start(orders, service);

    const blocked = await fetch(`${baseUrl}/customers/me/account-deletion/precheck`, {
      method: 'POST',
      headers: { Authorization: 'Bearer shopify-token-77' },
    });
    expect(blocked.status).toBe(200);
    expect(await blocked.json()).toEqual({
      result: 'blocked_open_order',
      order: {
        id: '900',
        shopifyOrderId: '900',
        reason: 'payment_review',
        orderName: '#1042',
      },
    });

    const deleted = await fetch(`${baseUrl}/customers/me/account-deletion`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Id-Token': 'fresh-id-token',
      },
    });
    expect(deleted.status).toBe(200);
    expect(await deleted.json()).toEqual({
      result: 'blocked_open_order',
      order: {
        id: '900',
        shopifyOrderId: '900',
        reason: 'payment_review',
        orderName: '#1042',
      },
    });
    expect(shopify.calls).toBe(0);
    expect(appData.calls).toBe(0);
  });

  it('requires a fresh login and reports Shopify erasure as requested', async () => {
    const { orders, service, fresh, shopify } = harness();
    await orders.upsertByShopifyOrderId(order({
      financialStatus: 'paid',
      fulfillmentStatus: 'fulfilled',
    }));
    await start(orders, service);

    fresh.mode = 'stale';
    const stale = await fetch(`${baseUrl}/customers/me/account-deletion`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Id-Token': 'fresh-id-token',
      },
    });
    expect(stale.status).toBe(401);
    expect(await stale.json()).toEqual({ error: 'stale_reauthentication' });
    expect(shopify.calls).toBe(0);

    fresh.mode = 'fresh';
    const deleted = await fetch(`${baseUrl}/customers/me/account-deletion`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Id-Token': 'fresh-id-token',
      },
    });
    expect(deleted.status).toBe(200);
    expect(await deleted.json()).toEqual({
      result: 'deleted',
      shopifyDataErasure: 'requested',
    });

    const again = await fetch(`${baseUrl}/customers/me/account-deletion`, {
      method: 'POST',
      headers: {
        Authorization: 'Bearer shopify-token-77',
        'X-Monetta-Id-Token': 'fresh-id-token',
      },
    });
    expect(again.status).toBe(200);
    expect(shopify.calls).toBe(1);
  });
});

describe('fresh Shopify login token', () => {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  const jwk = publicKey.export({ format: 'jwk' }) as JsonWebKey;
  jwk.kid = 'test-key';
  jwk.alg = 'RS256';
  jwk.use = 'sig';

  function idToken(claims: Record<string, unknown>): string {
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT', kid: 'test-key' })).toString('base64url');
    const payload = Buffer.from(JSON.stringify(claims)).toString('base64url');
    const signer = createSign('RSA-SHA256');
    signer.update(`${header}.${payload}`);
    signer.end();
    return `${header}.${payload}.${signer.sign(privateKey, 'base64url')}`;
  }

  function verifier(now: Date) {
    const fetchFn: typeof fetch = async (input) => {
      const url = String(input);
      if (url.endsWith('/.well-known/openid-configuration')) {
        return new Response(JSON.stringify({
          issuer: 'https://shopify.com/authentication/1',
          jwks_uri: 'https://shop.example/.well-known/jwks.json',
        }), { status: 200 });
      }
      return new Response(JSON.stringify({ keys: [jwk] }), { status: 200 });
    };
    return new ShopifyFreshLoginVerifier({
      shopDomain: 'monetta-staging.myshopify.com',
      customerTokens: {
        async resolveCustomerId(token: string) {
          return token === 'live-access' ? 'gid://shopify/Customer/77' : null;
        },
      },
      customerAccountClientId: 'mobile-client',
      maxAgeMs: 10 * 60 * 1000,
      fetchFn,
      now: () => now,
    });
  }

  it('accepts a recently signed id token and rejects a stale one', async () => {
    const now = new Date('2026-10-14T12:00:00Z');
    const nowSeconds = Math.floor(now.getTime() / 1000);
    const fresh = verifier(now);
    const accepted = await fresh.verify('live-access', idToken({
      iss: 'https://shopify.com/authentication/1',
      sub: 'gid://shopify/Customer/77',
      aud: 'mobile-client',
      iat: nowSeconds - 30,
      auth_time: nowSeconds - 30,
      exp: nowSeconds + 3600,
      email: 'ana@example.com',
    }));
    expect(accepted.status).toBe('fresh');
    if (accepted.status === 'fresh') expect(accepted.customerId).toBe('77');

    const otherCustomer = await fresh.verify('live-access', idToken({
      iss: 'https://shopify.com/authentication/1',
      sub: 'gid://shopify/Customer/88',
      aud: 'mobile-client',
      iat: nowSeconds - 30,
      auth_time: nowSeconds - 30,
      exp: nowSeconds + 3600,
    }));
    expect(otherCustomer).toEqual({ status: 'invalid' });

    const stale = await fresh.verify('live-access', idToken({
      iss: 'https://shopify.com/authentication/1',
      sub: 'gid://shopify/Customer/77',
      aud: 'mobile-client',
      iat: nowSeconds - 3600,
      auth_time: nowSeconds - 3600,
      exp: nowSeconds + 3600,
    }));
    expect(stale).toEqual({ status: 'stale', customerId: '77' });
    expect(JSON.stringify(stale)).not.toContain('@');
  });
});

describe('Customer Account order check', () => {
  const endpoint = 'https://shopify.example/account/customer/api/2026-07/graphql';

  function lookup(fetchFn: typeof fetch): CustomerAccountOrderLookup {
    return new CustomerAccountOrderLookup({
      shopDomain: 'monetta-staging.myshopify.com',
      graphQlEndpoint: endpoint,
      fetchFn,
    });
  }

  it('reads cancellation fields and follows pagination', async () => {
    const pages = [
      {
        data: {
          customer: {
            orders: {
              pageInfo: { hasNextPage: true, endCursor: 'cursor-2' },
              nodes: [{
                id: 'gid://shopify/Order/1',
                name: '#1001',
                financialStatus: 'PAID',
                fulfillmentStatus: 'UNFULFILLED',
                cancelledAt: '2026-04-01T00:00:00Z',
                cancelReason: 'CUSTOMER',
              }],
            },
          },
        },
      },
      {
        data: {
          customer: {
            orders: {
              pageInfo: { hasNextPage: false, endCursor: null },
              nodes: [{
                id: 'gid://shopify/Order/2',
                name: null,
                financialStatus: 'PENDING',
                fulfillmentStatus: 'UNFULFILLED',
                cancelledAt: null,
                cancelReason: null,
              }],
            },
          },
        },
      },
    ];
    let call = 0;
    const fetchFn: typeof fetch = async (_input, init) => {
      const body = JSON.parse(String(init?.body ?? '{}')) as { variables?: { after?: string | null } };
      expect(init?.headers).toMatchObject({ Authorization: 'shopper-token' });
      expect(JSON.stringify(init?.headers)).not.toContain('shpat_');
      if (call === 0) expect(body.variables?.after).toBeNull();
      if (call === 1) expect(body.variables?.after).toBe('cursor-2');
      const page = pages[call];
      call += 1;
      return new Response(JSON.stringify(page), { status: 200 });
    };

    const orders = await lookup(fetchFn).listOrders('shopper-token');
    expect(orders).toEqual([
      {
        id: 'gid://shopify/Order/1',
        name: '#1001',
        financialStatus: 'PAID',
        fulfillmentStatus: 'UNFULFILLED',
        cancelledAt: '2026-04-01T00:00:00Z',
        cancelReason: 'CUSTOMER',
        tags: [],
      },
      {
        id: 'gid://shopify/Order/2',
        name: null,
        financialStatus: 'PENDING',
        fulfillmentStatus: 'UNFULFILLED',
        cancelledAt: null,
        cancelReason: null,
        tags: [],
      },
    ]);
  });

  it('fails closed on HTTP errors, GraphQL errors, and a broken next page', async () => {
    const httpFail = lookup(async () => new Response('no', { status: 503 }));
    await expect(httpFail.listOrders('shopper-token')).rejects.toBeInstanceOf(OrderCheckUnavailableError);

    const graphqlFail = lookup(async () => new Response(JSON.stringify({
      errors: [{ message: 'customer ana@example.com unavailable' }],
    }), { status: 200 }));
    await expect(graphqlFail.listOrders('shopper-token')).rejects.toBeInstanceOf(OrderCheckUnavailableError);

    const truncated = lookup(async () => new Response(JSON.stringify({
      data: {
        customer: {
          orders: {
            pageInfo: { hasNextPage: true, endCursor: null },
            nodes: [],
          },
        },
      },
    }), { status: 200 }));
    await expect(truncated.listOrders('shopper-token')).rejects.toBeInstanceOf(OrderCheckUnavailableError);
  });

  it('fails closed with too_many_orders after 2000 orders', async () => {
    let pages = 0;
    const fetchFn: typeof fetch = async () => {
      pages += 1;
      return new Response(JSON.stringify({
        data: {
          customer: {
            orders: {
              pageInfo: { hasNextPage: true, endCursor: `cursor-${pages}` },
              nodes: [{
                id: `gid://shopify/Order/${pages}`,
                financialStatus: 'PAID',
                fulfillmentStatus: 'FULFILLED',
                cancelledAt: null,
                cancelReason: null,
              }],
            },
          },
        },
      }), { status: 200 });
    };
    await expect(lookup(fetchFn).listOrders('shopper-token')).rejects.toBeInstanceOf(TooManyOrdersError);
    expect(pages).toBe(40);
  });
});

describe('downstream erasure clients', () => {
  it('requests Shopify erasure and treats an existing request as requested', async () => {
    const calls: Array<{ url: string; body: string }> = [];
    const fetchFn: typeof fetch = async (input, init) => {
      calls.push({ url: String(input), body: String(init?.body ?? '') });
      if (String(input).includes('customerRequestDataErasure') || String(init?.body ?? '').includes('customerRequestDataErasure')) {
        return new Response(JSON.stringify({
          data: {
            customerRequestDataErasure: {
              customerId: 'gid://shopify/Customer/77',
              userErrors: [{ message: 'Erasure has already been requested' }],
            },
          },
        }), { status: 200 });
      }
      return new Response('no', { status: 500 });
    };
    const client = new ShopifyCustomerDataErasureClient({
      shopDomain: 'monetta-staging.myshopify.com',
      apiVersion: '2026-07',
      adminAccessToken: 'shpat_test_admin_token_value',
      fetchFn,
    });
    await expect(client.request('77')).resolves.toBe('requested');
    expect(calls[0]?.body).toContain('gid://shopify/Customer/77');
    expect(calls[0]?.body).not.toContain('shpat_test_admin_token_value');
  });

  it('deletes Firebase Auth and the profile, wishlist, and saved recommendations', async () => {
    const deleted: string[] = [];
    const fetchFn: typeof fetch = async (input, init) => {
      const url = String(input);
      const method = init?.method ?? 'GET';
      if (method === 'GET' && url.endsWith('/documents/customers/77')) {
        return new Response(JSON.stringify({
          fields: {
            firebaseUid: { stringValue: 'uid77' },
            email: { stringValue: 'ana@example.com' },
          },
        }), { status: 200 });
      }
      if (method === 'GET' && url.includes('/wishlist')) {
        return new Response(JSON.stringify({
          documents: [{ name: 'projects/monetta/databases/(default)/documents/customers/77/wishlist/bag' }],
        }), { status: 200 });
      }
      if (method === 'GET' && url.includes('/savedRecommendations')) {
        return new Response(JSON.stringify({ documents: [] }), { status: 200 });
      }
      if (method === 'GET') return new Response('{}', { status: 404 });
      if (method === 'POST' && url.endsWith('/accounts:delete')) {
        const body = JSON.parse(String(init?.body ?? '{}')) as { localId?: string };
        expect(body.localId).toBe('uid77');
        return new Response('{}', { status: 200 });
      }
      if (method === 'DELETE') {
        deleted.push(url);
        return new Response('', { status: 200 });
      }
      return new Response('no', { status: 500 });
    };
    const eraser = new FirebaseAppDataEraser({
      projectId: 'monetta-app',
      accessToken: async () => 'google-token',
      fetchFn,
    });
    const result = await eraser.erase('77');
    expect(result).toEqual({
      firebaseAuth: 'deleted',
      profile: 'deleted',
      wishlist: 'deleted',
      savedRecommendations: 'absent',
      firebaseUid: 'uid77',
    });
    expect(deleted.some((url) => url.endsWith('/customers/77'))).toBe(true);
    expect(deleted.some((url) => url.endsWith('/wishlist/bag'))).toBe(true);
    expect(JSON.stringify(deleted)).not.toContain('ana@example.com');
  });
});
