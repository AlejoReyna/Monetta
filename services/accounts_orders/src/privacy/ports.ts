import type { OpenOrderBlockReason } from './openOrderBlock.js';

export type FreshLoginDecision =
  | { readonly status: 'fresh'; readonly customerId: string; readonly authenticatedAt: string }
  | { readonly status: 'stale'; readonly customerId: string }
  | { readonly status: 'invalid' }
  | { readonly status: 'unavailable' };

export interface FreshLoginVerifier {
  verify(accessToken: string, idToken: string): Promise<FreshLoginDecision>;
}

export interface AppDataErasureResult {
  readonly firebaseAuth: 'deleted' | 'absent';
  readonly profile: 'deleted' | 'absent';
  readonly wishlist: 'deleted' | 'absent';
  readonly savedRecommendations: 'deleted' | 'absent';
  readonly firebaseUid: string | null;
}

export interface AppDataEraser {
  erase(shopifyCustomerId: string): Promise<AppDataErasureResult>;
}

export interface CustomerDataErasureResult {
  readonly appAccountId: string | null;
}

export interface CustomerDataEraser {
  /** Deletes or anonymizes this customer's rows in accounts_orders. Idempotent. */
  erase(shopifyCustomerId: string): Promise<CustomerDataErasureResult>;
}

export interface ShopifyCustomerErasureClient {
  /** Shopify processes erasure asynchronously. Idempotent when already requested. */
  request(shopifyCustomerId: string): Promise<'requested'>;
}

export interface AccountDeletionProgress {
  readonly shopifyCustomerId: string;
  readonly status: 'in_progress' | 'completed';
  readonly firebaseAuth: 'pending' | 'done';
  readonly firestore: 'pending' | 'done';
  readonly postgres: 'pending' | 'done';
  readonly shopifyErasure: 'pending' | 'requested';
  readonly appAccountId: string | null;
  readonly firebaseUid: string | null;
}

export interface AccountDeletionStateRepository {
  get(shopifyCustomerId: string): Promise<AccountDeletionProgress | null>;
  /** Inserts an in-progress row. A completed row is left completed. */
  claim(shopifyCustomerId: string): Promise<AccountDeletionProgress>;
  save(progress: AccountDeletionProgress): Promise<void>;
}

export interface AccountDeletionAuditEntry {
  readonly shopifyCustomerId: string;
  readonly appAccountId: string | null;
  readonly firebaseUid: string | null;
  readonly result: string;
  readonly steps: Readonly<Record<string, string>>;
  readonly createdAt: string;
}

export interface AccountDeletionAuditRepository {
  append(entry: Omit<AccountDeletionAuditEntry, 'createdAt'> & { readonly createdAt?: string }): Promise<AccountDeletionAuditEntry>;
  list(shopifyCustomerId: string): Promise<readonly AccountDeletionAuditEntry[]>;
}

export interface ShopifyListedOrder {
  readonly id: string;
  readonly financialStatus: string | null;
  readonly fulfillmentStatus: string | null;
  readonly tags: readonly string[];
  readonly cancelledAt: string | null;
  readonly cancelReason: string | null;
}

/** Live Shopify orders for the deletion block check. Throws when it cannot finish. */
export interface ShopifyCustomerOrderLookup {
  listOrders(accessToken: string): Promise<readonly ShopifyListedOrder[]>;
}

export interface BlockingOrderRef {
  readonly id: string;
  readonly shopifyOrderId: string | null;
  readonly reason: OpenOrderBlockReason;
}

export type DeletionCredential = 'customer_account' | 'monetta_session';

export type AccountDeletionPrecheck =
  | { readonly result: 'clear' }
  | { readonly result: 'blocked_open_order'; readonly order: BlockingOrderRef }
  | { readonly result: 'deleted'; readonly shopifyDataErasure: 'requested' }
  | { readonly result: 'order_check_unavailable' }
  | { readonly result: 'reauth_required' }
  | { readonly result: 'too_many_orders' };

export type AccountDeletionExecute =
  | { readonly result: 'deleted'; readonly shopifyDataErasure: 'requested' }
  | { readonly result: 'blocked_open_order'; readonly order: BlockingOrderRef }
  | { readonly result: 'stale_reauthentication' }
  | { readonly result: 'unauthorized' }
  | { readonly result: 'unavailable' }
  | { readonly result: 'failed' }
  | { readonly result: 'order_check_unavailable' }
  | { readonly result: 'too_many_orders' };
